import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/auth/session_events.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/community/domain/entities/community_comment.dart';
import 'package:motohub/features/community/domain/entities/community_like_state.dart';
import 'package:motohub/features/community/domain/entities/community_post.dart';
import 'package:motohub/features/community/domain/entities/paged_community_posts.dart';
import 'package:motohub/features/community/domain/entities/paged_community_comments.dart';
import 'package:motohub/features/community/domain/entities/post_author.dart';
import 'package:motohub/features/community/domain/repositories/community_repository.dart';
import 'package:motohub/features/community/domain/usecases/create_community_post.dart';
import 'package:motohub/features/community/domain/usecases/delete_community_post.dart';
import 'package:motohub/features/community/domain/usecases/get_community_feed.dart';
import 'package:motohub/features/community/presentation/cubit/community_feed_cubit.dart';

void main() {
  test('loads pages, deduplicates posts and stops after the last page', () async {
    final repository = _FakeCommunityRepository(pages: {
      1: _page([_post('one'), _post('two')], page: 1, totalPages: 2, totalCount: 3),
      2: _page([_post('two'), _post('three')], page: 2, totalPages: 2, totalCount: 3),
    });
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.loadInitial();
    await cubit.loadMore();
    await cubit.loadMore();

    expect(cubit.state.items.map((post) => post.id), ['one', 'two', 'three']);
    expect(repository.requestedPages, [1, 2]);
  });

  test('refresh failure preserves the valid feed', () async {
    final repository = _FakeCommunityRepository(
      pages: {1: _page([_post('one')], page: 1, totalPages: 1, totalCount: 1)},
      failRefresh: true,
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.loadInitial();
    await cubit.refresh();

    expect(cubit.state.items.map((post) => post.id), ['one']);
    expect(cubit.state.failure, 'No se pudo actualizar.');
  });

  test('create trims content, prevents double submit and inserts backend post', () async {
    final createCompleter = Completer<CommunityPost>();
    final repository = _FakeCommunityRepository(createFuture: createCompleter.future);
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    final first = cubit.createPost('  nuevo post  ');
    final second = cubit.createPost('otro post');
    createCompleter.complete(_post('created'));
    final result = await first;

    expect(result?.id, 'created');
    expect(repository.createdContents, ['nuevo post']);
    expect(await second, isNull);
    expect(cubit.state.items.single.id, 'created');
  });

  test('stale feed response cannot repopulate state after session invalidation', () async {
    final pending = Completer<PagedCommunityPosts>();
    final sessionEvents = SessionEvents();
    final repository = _FakeCommunityRepository(feedFuture: pending.future);
    final cubit = CommunityFeedCubit(GetCommunityFeed(repository), CreateCommunityPost(repository), DeleteCommunityPost(repository), sessionEvents);
    addTearDown(() async {
      await cubit.close();
      await sessionEvents.dispose();
    });

    final load = cubit.loadInitial();
    sessionEvents.invalidate();
    pending.complete(_page([_post('stale')], page: 1, totalPages: 1, totalCount: 1));
    await load;

    expect(cubit.state.items, isEmpty);
    expect(cubit.state.isInitialLoading, isFalse);
  });

  test('stale delete releases its flag without deleting the current feed and allows retry', () async {
    final pendingDelete = Completer<void>();
    final repository = _FakeCommunityRepository(
      pages: {1: _page([_post('one')], page: 1, totalPages: 1, totalCount: 1)},
      deleteFutures: [pendingDelete.future, Future<void>.value()],
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.loadInitial();
    final staleDelete = cubit.deletePost('one');
    await cubit.refresh();
    pendingDelete.complete();
    await staleDelete;

    expect(cubit.state.items.map((post) => post.id), ['one']);
    expect(cubit.state.deletingPostId, isNull);
    expect(await cubit.deletePost('one'), isTrue);
    expect(cubit.state.items, isEmpty);
  });

  test('stale refresh releases its flag without replacing feed data', () async {
    final pendingRefresh = Completer<PagedCommunityPosts>();
    final repository = _FakeCommunityRepository(
      pages: {1: _page([_post('one')], page: 1, totalPages: 1, totalCount: 1)},
      feedFutures: [
        Future.value(_page([_post('one')], page: 1, totalPages: 1, totalCount: 1)),
        pendingRefresh.future,
      ],
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.loadInitial();
    final staleRefresh = cubit.refresh();
    final created = await cubit.createPost('current');
    pendingRefresh.complete(_page([_post('stale')], page: 1, totalPages: 1, totalCount: 1));
    await staleRefresh;

    expect(created?.id, 'created');
    expect(cubit.state.isRefreshing, isFalse);
    expect(cubit.state.items.map((post) => post.id).toSet(), {'created', 'one'});
  });

  test('stale create releases submitting without inserting and allows a new create', () async {
    final pendingCreate = Completer<CommunityPost>();
    final repository = _FakeCommunityRepository(
      createFutures: [pendingCreate.future, Future.value(_post('new'))],
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    final staleCreate = cubit.createPost('stale');
    await cubit.refresh();
    pendingCreate.complete(_post('stale'));
    await staleCreate;

    expect(cubit.state.items, isEmpty);
    expect(cubit.state.isSubmitting, isFalse);
    expect((await cubit.createPost('current'))?.id, 'new');
    expect(cubit.state.items.single.id, 'new');
  });

  test('stale delete cannot clear a newer delete flag after session invalidation', () async {
    final oldDelete = Completer<void>();
    final newDelete = Completer<void>();
    final sessionEvents = SessionEvents();
    final repository = _FakeCommunityRepository(
      pages: {1: _page([_post('one')], page: 1, totalPages: 1, totalCount: 1)},
      deleteFutures: [oldDelete.future, newDelete.future],
    );
    final cubit = CommunityFeedCubit(GetCommunityFeed(repository), CreateCommunityPost(repository), DeleteCommunityPost(repository), sessionEvents);
    addTearDown(() async {
      await cubit.close();
      await sessionEvents.dispose();
    });

    await cubit.loadInitial();
    final staleDelete = cubit.deletePost('one');
    sessionEvents.invalidate();
    await Future<void>.delayed(Duration.zero);
    final currentDelete = cubit.deletePost('one');
    oldDelete.complete();
    await staleDelete;

    expect(cubit.state.deletingPostId, 'one');
    newDelete.complete();
    expect(await currentDelete, isTrue);
  });

  test('delete failure keeps the post visible', () async {
    final repository = _FakeCommunityRepository(
      pages: {1: _page([_post('one')], page: 1, totalPages: 1, totalCount: 1)},
      deleteFailure: true,
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.loadInitial();
    expect(await cubit.deletePost('one'), isFalse);
    expect(cubit.state.items.single.id, 'one');
    expect(cubit.state.operationFailure, 'No se pudo eliminar.');
  });
}

CommunityFeedCubit _cubit(_FakeCommunityRepository repository) => CommunityFeedCubit(
      GetCommunityFeed(repository),
      CreateCommunityPost(repository),
      DeleteCommunityPost(repository),
    );

PagedCommunityPosts _page(List<CommunityPost> items, {required int page, required int totalPages, required int totalCount}) => PagedCommunityPosts(
      items: items,
      page: page,
      pageSize: 20,
      totalCount: totalCount,
      totalPages: totalPages,
    );

CommunityPost _post(String id) => CommunityPost(
      id: id,
      author: const PostAuthor(userId: 'user-1', displayName: 'Rider'),
      content: id,
      publishedAt: DateTime.utc(2026, 9, 24),
      likeCount: 0,
      commentCount: 0,
      likedByCurrentUser: false,
      isOwner: true,
    );

class _FakeCommunityRepository implements CommunityRepository {
  _FakeCommunityRepository({this.pages = const {}, this.feedFuture, this.feedFutures = const [], this.createFuture, this.createFutures = const [], this.failRefresh = false, this.deleteFailure = false, this.deleteFutures = const []});

  final Map<int, PagedCommunityPosts> pages;
  final Future<PagedCommunityPosts>? feedFuture;
  final List<Future<PagedCommunityPosts>> feedFutures;
  final Future<CommunityPost>? createFuture;
  final List<Future<CommunityPost>> createFutures;
  final bool failRefresh;
  final bool deleteFailure;
  final List<Future<void>> deleteFutures;
  final requestedPages = <int>[];
  final createdContents = <String>[];
  var _requestCount = 0;
  var _feedCount = 0;
  var _createCount = 0;
  var _deleteCount = 0;

  @override
  Future<PagedCommunityPosts> getFeed({int page = 1, int pageSize = 20}) {
    requestedPages.add(page);
    if (_feedCount < feedFutures.length) return feedFutures[_feedCount++];
    if (feedFuture != null) return feedFuture!;
    if (failRefresh && _requestCount++ > 0) return Future.error(const NetworkFailure('No se pudo actualizar.'));
    return Future.value(pages[page] ?? _page([], page: page, totalPages: page, totalCount: 0));
  }

  @override
  Future<CommunityPost> getPost(String postId) => Future.value(_post(postId));

  @override
  Future<CommunityLikeState> likePost(String postId) => Future.value(const CommunityLikeState(likedByCurrentUser: true, likeCount: 1));

  @override
  Future<CommunityLikeState> unlikePost(String postId) => Future.value(const CommunityLikeState(likedByCurrentUser: false, likeCount: 0));

  @override
  Future<PagedCommunityComments> getComments({required String postId, int page = 1, int pageSize = 20}) => Future.value(PagedCommunityComments(items: const [], page: page, pageSize: pageSize, totalCount: 0, totalPages: 0));

  @override
  Future<CommunityComment> createComment({required String postId, required String content}) => Future.error(UnimplementedError());

  @override
  Future<void> deleteComment({required String postId, required String commentId}) => Future.value();

  @override
  Future<CommunityPost> createPost(String content) {
    createdContents.add(content);
    if (_createCount < createFutures.length) return createFutures[_createCount++];
    return createFuture ?? Future.value(_post('created'));
  }

  @override
  Future<void> deletePost(String postId) {
    if (_deleteCount < deleteFutures.length) return deleteFutures[_deleteCount++];
    return deleteFailure ? Future.error(const NetworkFailure('No se pudo eliminar.')) : Future.value();
  }
}
