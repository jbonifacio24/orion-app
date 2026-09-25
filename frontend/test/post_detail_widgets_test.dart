import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:motohub/features/community/presentation/pages/community_post_detail_page.dart';
import 'package:motohub/features/community/presentation/widgets/community_comment_tile.dart';

void main() {
  testWidgets('detail shows the post and empty comments state', (tester) async {
    final cubit = _cubit(_FakeRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(_app(BlocProvider.value(value: cubit, child: const CommunityPostDetailPage(postId: 'post-1'))));
    await tester.pumpAndSettle();

    expect(find.text('Post content'), findsOneWidget);
    expect(find.text('Aún no hay comentarios.'), findsOneWidget);
  });

  testWidgets('detail shows post failure and retries', (tester) async {
    final repository = _FakeRepository()..failFirstPost = true;
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(_app(BlocProvider.value(value: cubit, child: const CommunityPostDetailPage(postId: 'post-1'))));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar la publicación.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Post content'), findsOneWidget);
  });

  testWidgets('comment delete is visible only for its owner', (tester) async {
    await tester.pumpWidget(_app(CommunityCommentTile(comment: CommunityComment(
      id: 'comment-1',
      postId: 'post-1',
      author: const PostAuthor(userId: 'user-1', displayName: 'Rider'),
      content: 'Text',
      createdAt: DateTime(2026, 9, 24),
      isOwner: true,
    ), onDelete: _noop)));
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.pumpWidget(_app(CommunityCommentTile(comment: CommunityComment(
      id: 'comment-1',
      postId: 'post-1',
      author: const PostAuthor(userId: 'user-1', displayName: 'Rider'),
      content: 'Text',
      createdAt: DateTime(2026, 9, 24),
      isOwner: false,
    ))));
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}

void _noop() {}

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('es'), Locale('en')],
      home: child,
    );

PostDetailCubit _cubit(_FakeRepository repository) => PostDetailCubit(
      GetCommunityPost(repository),
      GetCommunityComments(repository),
      LikeCommunityPost(repository),
      UnlikeCommunityPost(repository),
      CreateCommunityComment(repository),
      DeleteCommunityComment(repository),
    );

CommunityPost _post() => const CommunityPost(
      id: 'post-1',
      author: PostAuthor(userId: 'user-1', displayName: 'Rider'),
      content: 'Post content',
      publishedAt: null,
      likeCount: 0,
      commentCount: 0,
      likedByCurrentUser: false,
      isOwner: false,
    );

class _FakeRepository implements CommunityRepository {
  var failFirstPost = false;
  var _postCalls = 0;

  @override
  Future<PagedCommunityPosts> getFeed({int page = 1, int pageSize = 20}) => Future.value(const PagedCommunityPosts(items: [], page: 1, pageSize: 20, totalCount: 0, totalPages: 0));

  @override
  Future<CommunityPost> getPost(String postId) {
    _postCalls++;
    if (failFirstPost && _postCalls == 1) return Future.error(const NetworkFailure('No se pudo cargar la publicación.'));
    return Future.value(_post());
  }

  @override
  Future<CommunityPost> createPost(String content) => Future.value(_post());

  @override
  Future<void> deletePost(String postId) => Future.value();

  @override
  Future<CommunityLikeState> likePost(String postId) => Future.value(const CommunityLikeState(likedByCurrentUser: true, likeCount: 1));

  @override
  Future<CommunityLikeState> unlikePost(String postId) => Future.value(const CommunityLikeState(likedByCurrentUser: false, likeCount: 0));

  @override
  Future<PagedCommunityComments> getComments({required String postId, int page = 1, int pageSize = 20}) => Future.value(PagedCommunityComments(items: const [], page: page, pageSize: pageSize, totalCount: 0, totalPages: 0));

  @override
  Future<CommunityComment> createComment({required String postId, required String content}) => Future.value(CommunityComment(id: 'comment-1', postId: 'post-1', author: const PostAuthor(userId: 'user-1', displayName: 'Rider'), content: 'Text', createdAt: DateTime(2026, 9, 24), isOwner: true));

  @override
  Future<void> deleteComment({required String postId, required String commentId}) => Future.value();
}
