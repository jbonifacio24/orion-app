import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/features/community/domain/entities/community_post.dart';
import 'package:motohub/features/community/domain/entities/paged_community_posts.dart';
import 'package:motohub/features/community/domain/entities/post_author.dart';
import 'package:motohub/features/community/domain/repositories/community_repository.dart';
import 'package:motohub/features/community/domain/usecases/create_community_post.dart';
import 'package:motohub/features/community/domain/usecases/delete_community_post.dart';
import 'package:motohub/features/community/domain/usecases/get_community_feed.dart';
import 'package:motohub/features/community/presentation/cubit/community_feed_cubit.dart';
import 'package:motohub/features/community/presentation/pages/create_community_post_page.dart';
import 'package:motohub/features/community/presentation/widgets/community_post_card.dart';

void main() {
  testWidgets('post card only exposes delete for the owner', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CommunityPostCard(post: _post(isOwner: true), onDelete: () {})));
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: CommunityPostCard(post: CommunityPost(
      id: 'post-1',
      author: PostAuthor(userId: 'user-1', displayName: 'Rider'),
      content: 'Content',
      publishedAt: null,
      likeCount: 2,
      commentCount: 1,
      likedByCurrentUser: false,
      isOwner: false,
    ))));
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('create page shows the localized form and disables over-limit content', (tester) async {
    final cubit = _cubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('es'), Locale('en')],
      home: BlocProvider.value(value: cubit, child: const CreateCommunityPostPage()),
    ));

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.decoration?.labelText, '¿Qué quieres compartir?');
    expect(find.text('0 / 5000'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'x' * 5001);
    await tester.pump();

    expect(find.text('5001 / 5000'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}

CommunityPost _post({required bool isOwner}) => CommunityPost(
      id: 'post-1',
      author: const PostAuthor(userId: 'user-1', displayName: 'Rider'),
      content: 'Content',
      publishedAt: null,
      likeCount: 2,
      commentCount: 1,
      likedByCurrentUser: false,
      isOwner: isOwner,
    );

CommunityFeedCubit _cubit() {
  final repository = _FakeRepository();
  return CommunityFeedCubit(GetCommunityFeed(repository), CreateCommunityPost(repository), DeleteCommunityPost(repository));
}

class _FakeRepository implements CommunityRepository {
  @override
  Future<PagedCommunityPosts> getFeed({int page = 1, int pageSize = 20}) => Future.value(const PagedCommunityPosts(items: [], page: 1, pageSize: 20, totalCount: 0, totalPages: 0));

  @override
  Future<CommunityPost> createPost(String content) => Future.value(_post(isOwner: true));

  @override
  Future<void> deletePost(String postId) async {}
}
