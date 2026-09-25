import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/auth/session_events.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/community/domain/entities/community_comment.dart';
import 'package:motohub/features/community/domain/entities/community_like_state.dart';
import 'package:motohub/features/community/domain/entities/community_post.dart';
import 'package:motohub/features/community/domain/entities/paged_community_comments.dart';
import 'package:motohub/features/community/domain/entities/paged_community_posts.dart';
import 'package:motohub/features/community/domain/entities/post_author.dart';
import 'package:motohub/features/community/domain/repositories/community_repository.dart';
import 'package:motohub/features/community/domain/usecases/create_community_comment.dart';
import 'package:motohub/features/community/domain/usecases/delete_community_comment.dart';
import 'package:motohub/features/community/domain/usecases/get_community_comments.dart';
import 'package:motohub/features/community/domain/usecases/get_community_post.dart';
import 'package:motohub/features/community/domain/usecases/like_community_post.dart';
import 'package:motohub/features/community/domain/usecases/unlike_community_post.dart';
import 'package:motohub/features/community/presentation/cubit/post_detail_cubit.dart';

void main() {
  test('loads post and comments, paginates and deduplicates comments', () async {
    final repository = _FakeRepository(
      comments: {
        1: _comments([_comment('one'), _comment('two')], page: 1, totalPages: 2, totalCount: 3),
        2: _comments([_comment('two'), _comment('three')], page: 2, totalPages: 2, totalCount: 3),
      },
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.load('post-1');
    await cubit.loadMoreComments();
    await cubit.loadMoreComments();

    expect(cubit.state.post?.id, 'post-1');
    expect(cubit.state.comments.map((comment) => comment.id), ['one', 'two', 'three']);
    expect(repository.requestedCommentPages, [1, 2]);
  });

  test('comments failure preserves a loaded post', () async {
    final repository = _FakeRepository(commentsFailure: true);
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.load('post-1');

    expect(cubit.state.post?.id, 'post-1');
    expect(cubit.state.comments, isEmpty);
    expect(cubit.state.commentsFailure, 'No se pudieron cargar los comentarios.');
  });

  test('load more failure preserves existing comments and retry remains possible', () async {
    final repository = _FakeRepository(
      comments: {1: _comments([_comment('one')], page: 1, totalPages: 2, totalCount: 2)},
      commentFailures: {2},
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.load('post-1');
    await cubit.loadMoreComments();

    expect(cubit.state.comments.map((comment) => comment.id), ['one']);
    expect(cubit.state.isLoadingMoreComments, isFalse);
    expect(cubit.state.commentsFailure, isNotNull);
  });

  test('load-more retry requests the failed page and preserves previous pages', () async {
    final repository = _FakeRepository(
      comments: {
        1: _comments([_comment('one')], page: 1, totalPages: 3, totalCount: 3),
        2: _comments([_comment('two')], page: 2, totalPages: 3, totalCount: 3),
        3: _comments([_comment('two'), _comment('three')], page: 3, totalPages: 3, totalCount: 3),
      },
      commentFailureCounts: {3: 1},
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.load('post-1');
    await cubit.loadMoreComments();
    await cubit.loadMoreComments();

    expect(cubit.state.comments.map((comment) => comment.id), ['one', 'two']);
    expect(cubit.state.page, 2);

    await cubit.retryComments();

    expect(repository.requestedCommentPages, [1, 2, 3, 3]);
    expect(cubit.state.comments.map((comment) => comment.id), ['one', 'two', 'three']);
    expect(cubit.state.comments.map((comment) => comment.id).toSet(), hasLength(3));
    expect(cubit.state.page, 3);
    expect(cubit.state.hasMoreComments, isFalse);
    expect(cubit.state.commentsFailure, isNull);
  });

  test('failed load-more retry keeps the failed page and allows another retry', () async {
    final repository = _FakeRepository(
      comments: {
        1: _comments([_comment('one')], page: 1, totalPages: 3, totalCount: 3),
        2: _comments([_comment('two')], page: 2, totalPages: 3, totalCount: 3),
        3: _comments([_comment('three')], page: 3, totalPages: 3, totalCount: 3),
      },
      commentFailureCounts: {3: 2},
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.load('post-1');
    await cubit.loadMoreComments();
    await cubit.loadMoreComments();
    await cubit.retryComments();

    expect(repository.requestedCommentPages, [1, 2, 3, 3]);
    expect(cubit.state.comments.map((comment) => comment.id), ['one', 'two']);
    expect(cubit.state.page, 2);
    expect(cubit.state.commentsFailure, isNotNull);
    expect(cubit.state.hasMoreComments, isTrue);

    await cubit.retryComments();

    expect(repository.requestedCommentPages, [1, 2, 3, 3, 3]);
    expect(cubit.state.comments.map((comment) => comment.id), ['one', 'two', 'three']);
    expect(cubit.state.page, 3);
  });

  test('initial comments retry requests page one with reset behavior', () async {
    final repository = _FakeRepository(
      comments: {1: _comments([_comment('one')], page: 1, totalPages: 1, totalCount: 1)},
      commentsFailure: true,
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.load('post-1');
    repository.commentsFailure = false;
    await cubit.retryComments();

    expect(repository.requestedCommentPages, [1, 1]);
    expect(cubit.state.comments.map((comment) => comment.id), ['one']);
    expect(cubit.state.page, 1);
    expect(cubit.state.commentsFailure, isNull);
  });

  test('like and unlike use the server-confirmed state and recover from failure', () async {
    final repository = _FakeRepository(
      likeStates: [
        Future.value(const CommunityLikeState(likedByCurrentUser: true, likeCount: 7)),
        Future.value(const CommunityLikeState(likedByCurrentUser: false, likeCount: 6)),
      ],
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.load('post-1');
    expect(await cubit.like(), isTrue);
    expect(cubit.state.post?.likedByCurrentUser, isTrue);
    expect(cubit.state.post?.likeCount, 7);
    expect(await cubit.unlike(), isTrue);
    expect(cubit.state.post?.likedByCurrentUser, isFalse);
    expect(cubit.state.post?.likeCount, 6);

    repository.likeFailure = true;
    expect(await cubit.like(), isFalse);
    expect(cubit.state.post?.likedByCurrentUser, isFalse);
    expect(cubit.state.isLikeProcessing, isFalse);
  });

  test('comment validation, double submit and success use the backend comment', () async {
    final pendingCreate = Completer<CommunityComment>();
    final repository = _FakeRepository(createComments: [pendingCreate.future, Future.value(_comment('created'))]);
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.load('post-1');
    expect(await cubit.createComment('x' * 2001), isNull);
    expect(repository.createdContents, isEmpty);
    final first = cubit.createComment('  valid comment  ');
    expect(await cubit.createComment('second'), isNull);
    pendingCreate.complete(_comment('created'));
    expect((await first)?.id, 'created');
    expect(repository.createdContents, ['valid comment']);
    expect(cubit.state.comments.single.id, 'created');
    expect(cubit.state.isCommentSubmitting, isFalse);
    expect(await cubit.createComment('next'), isNotNull);
  });

  test('comment validation accepts exactly 2000 characters and rejects whitespace', () async {
    final repository = _FakeRepository();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load('post-1');

    expect(await cubit.createComment('   '), isNull);
    expect(await cubit.createComment('x' * 2000), isNotNull);
    expect(repository.createdContents.single.length, 2000);
  });

  test('owner delete is server-confirmed and failure preserves the comment', () async {
    final repository = _FakeRepository(
      comments: {1: _comments([_comment('one', isOwner: true)], page: 1, totalPages: 1, totalCount: 1)},
    )..deleteFailure = true;
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load('post-1');
    final comment = _comment('one', isOwner: true);

    expect(await cubit.deleteComment(comment), isFalse);
    expect(cubit.state.comments.map((item) => item.id), ['one']);
    expect(cubit.state.deletingCommentId, isNull);

    repository.deleteFailure = false;
    expect(await cubit.deleteComment(comment), isTrue);
    expect(cubit.state.comments, isEmpty);
  });

  test('stale session load cannot populate the next session', () async {
    final pendingPost = Completer<CommunityPost>();
    final pendingComments = Completer<PagedCommunityComments>();
    final sessionEvents = SessionEvents();
    final repository = _FakeRepository(postFuture: pendingPost.future, commentsFuture: pendingComments.future);
    final cubit = _cubit(repository, sessionEvents);
    addTearDown(() async {
      await cubit.close();
      await sessionEvents.dispose();
    });

    final load = cubit.load('session-a');
    sessionEvents.invalidate();
    pendingPost.complete(_post('session-a'));
    pendingComments.complete(_comments([_comment('old')], page: 1, totalPages: 1, totalCount: 1));
    await load;

    expect(cubit.state.post, isNull);
    expect(cubit.state.comments, isEmpty);
    expect(cubit.state.isPostLoading, isFalse);
    expect(cubit.state.isCommentsLoading, isFalse);
  });

  test('stale like cannot change or clear the like operation of a new session', () async {
    final oldLike = Completer<CommunityLikeState>();
    final newLike = Completer<CommunityLikeState>();
    final sessionEvents = SessionEvents();
    final repository = _FakeRepository(likeStates: [oldLike.future, newLike.future]);
    final cubit = _cubit(repository, sessionEvents);
    addTearDown(() async {
      await cubit.close();
      await sessionEvents.dispose();
    });

    await cubit.load('post-a');
    final staleOperation = cubit.like();
    sessionEvents.invalidate();
    await Future<void>.delayed(Duration.zero);
    await cubit.load('post-b');
    final currentOperation = cubit.like();
    oldLike.complete(const CommunityLikeState(likedByCurrentUser: true, likeCount: 99));
    expect(await staleOperation, isFalse);

    expect(cubit.state.post?.id, 'post-b');
    expect(cubit.state.post?.likedByCurrentUser, isFalse);
    expect(cubit.state.isLikeProcessing, isTrue);
    newLike.complete(const CommunityLikeState(likedByCurrentUser: true, likeCount: 4));
    expect(await currentOperation, isTrue);
    expect(cubit.state.post?.likeCount, 4);
  });

  test('stale create and delete do not clear newer operation flags', () async {
    final oldCreate = Completer<CommunityComment>();
    final newCreate = Completer<CommunityComment>();
    final oldDelete = Completer<void>();
    final newDelete = Completer<void>();
    final sessionEvents = SessionEvents();
    final repository = _FakeRepository(
      createComments: [oldCreate.future, newCreate.future],
      deleteFutures: [oldDelete.future, newDelete.future],
    );
    final cubit = _cubit(repository, sessionEvents);
    addTearDown(() async {
      await cubit.close();
      await sessionEvents.dispose();
    });

    await cubit.load('post-a');
    final staleCreate = cubit.createComment('old');
    sessionEvents.invalidate();
    await Future<void>.delayed(Duration.zero);
    await cubit.load('post-b');
    final currentCreate = cubit.createComment('new');
    oldCreate.complete(_comment('old'));
    expect(await staleCreate, isNull);
    expect(cubit.state.isCommentSubmitting, isTrue);
    newCreate.complete(_comment('new'));
    expect(await currentCreate, isNotNull);

    final staleDelete = cubit.deleteComment(_comment('delete', isOwner: true));
    sessionEvents.invalidate();
    await Future<void>.delayed(Duration.zero);
    await cubit.load('post-c');
    final currentDelete = cubit.deleteComment(_comment('delete', isOwner: true));
    oldDelete.complete();
    expect(await staleDelete, isFalse);
    expect(cubit.state.deletingCommentId, 'delete');
    newDelete.complete();
    expect(await currentDelete, isTrue);
  });
}

PostDetailCubit _cubit(_FakeRepository repository, [SessionEvents? sessionEvents]) => PostDetailCubit(
      GetCommunityPost(repository),
      GetCommunityComments(repository),
      LikeCommunityPost(repository),
      UnlikeCommunityPost(repository),
      CreateCommunityComment(repository),
      DeleteCommunityComment(repository),
      sessionEvents,
    );

CommunityPost _post(String id) => CommunityPost(
      id: id,
      author: const PostAuthor(userId: 'user-1', displayName: 'Rider'),
      content: id,
      publishedAt: DateTime.utc(2026, 9, 24),
      likeCount: 0,
      commentCount: 1,
      likedByCurrentUser: false,
      isOwner: true,
    );

CommunityComment _comment(String id, {bool isOwner = false}) => CommunityComment(
      id: id,
      postId: 'post-1',
      author: const PostAuthor(userId: 'user-1', displayName: 'Rider'),
      content: id,
      createdAt: DateTime.utc(2026, 9, 24),
      isOwner: isOwner,
    );

PagedCommunityComments _comments(List<CommunityComment> items, {required int page, required int totalPages, required int totalCount}) => PagedCommunityComments(
      items: items,
      page: page,
      pageSize: 20,
      totalCount: totalCount,
      totalPages: totalPages,
    );

class _FakeRepository implements CommunityRepository {
  _FakeRepository({
    this.comments = const {},
    this.commentsFailure = false,
    this.commentFailures = const {},
    this.commentFailureCounts = const {},
    this.postFuture,
    this.commentsFuture,
    this.likeStates = const [],
    this.createComments = const [],
    this.deleteFutures = const [],
  });

  final Map<int, PagedCommunityComments> comments;
  bool commentsFailure;
  final Set<int> commentFailures;
  final Map<int, int> commentFailureCounts;
  final Future<CommunityPost>? postFuture;
  final Future<PagedCommunityComments>? commentsFuture;
  final List<Future<CommunityLikeState>> likeStates;
  final List<Future<CommunityComment>> createComments;
  final List<Future<void>> deleteFutures;
  final requestedCommentPages = <int>[];
  final createdContents = <String>[];
  var likeFailure = false;
  var deleteFailure = false;
  var _likeIndex = 0;
  var _createIndex = 0;
  var _deleteIndex = 0;

  @override
  Future<PagedCommunityPosts> getFeed({int page = 1, int pageSize = 20}) => Future.value(PagedCommunityPosts(items: [_post('post-1')], page: page, pageSize: pageSize, totalCount: 1, totalPages: 1));

  @override
  Future<CommunityPost> getPost(String postId) => postFuture ?? Future.value(_post(postId));

  @override
  Future<CommunityPost> createPost(String content) => Future.value(_post('created'));

  @override
  Future<void> deletePost(String postId) => Future.value();

  @override
  Future<CommunityLikeState> likePost(String postId) {
    if (likeFailure) return Future.error(const NetworkFailure('No se pudo actualizar el like.'));
    if (_likeIndex < likeStates.length) return likeStates[_likeIndex++];
    return Future.value(const CommunityLikeState(likedByCurrentUser: true, likeCount: 1));
  }

  @override
  Future<CommunityLikeState> unlikePost(String postId) {
    if (likeFailure) return Future.error(const NetworkFailure('No se pudo actualizar el like.'));
    if (_likeIndex < likeStates.length) return likeStates[_likeIndex++];
    return Future.value(const CommunityLikeState(likedByCurrentUser: false, likeCount: 0));
  }

  @override
  Future<PagedCommunityComments> getComments({required String postId, int page = 1, int pageSize = 20}) {
    requestedCommentPages.add(page);
    if (commentsFuture != null) return commentsFuture!;
    if (commentsFailure) return Future.error(const NetworkFailure('No se pudieron cargar los comentarios.'));
    if (commentFailures.contains(page)) return Future.error(const NetworkFailure('No se pudieron cargar los comentarios.'));
    final remainingFailures = commentFailureCounts[page] ?? 0;
    if (remainingFailures > 0) {
      commentFailureCounts[page] = remainingFailures - 1;
      return Future.error(const NetworkFailure('No se pudieron cargar los comentarios.'));
    }
    return Future.value(comments[page] ?? _comments(const [], page: page, totalPages: page, totalCount: 0));
  }

  @override
  Future<CommunityComment> createComment({required String postId, required String content}) {
    createdContents.add(content);
    if (_createIndex < createComments.length) return createComments[_createIndex++];
    return Future.value(_comment('created', isOwner: true));
  }

  @override
  Future<void> deleteComment({required String postId, required String commentId}) {
    if (deleteFailure) return Future.error(const NetworkFailure('No se pudo eliminar el comentario.'));
    if (_deleteIndex < deleteFutures.length) return deleteFutures[_deleteIndex++];
    return Future.value();
  }
}
