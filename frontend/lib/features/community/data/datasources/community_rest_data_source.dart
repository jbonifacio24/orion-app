import 'package:dio/dio.dart';

import '../models/community_models.dart';

class CommunityRestDataSource {
  const CommunityRestDataSource(this._dio);

  final Dio _dio;

  Future<PagedCommunityPostsModel> getFeed({int page = 1, int pageSize = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/posts',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PagedCommunityPostsModel.fromJson(response.data!);
  }

  Future<CommunityPostModel> getPost(String postId) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/posts/$postId');
    return CommunityPostModel.fromJson(response.data!);
  }

  Future<CommunityPostModel> createPost(String content) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/posts',
      data: {'content': content},
    );
    return CommunityPostModel.fromJson(response.data!);
  }

  Future<void> deletePost(String postId) async {
    await _dio.delete<void>('/api/posts/$postId');
  }

  Future<CommunityLikeStateModel> likePost(String postId) async {
    final response = await _dio.post<Map<String, dynamic>>('/api/posts/$postId/likes');
    return CommunityLikeStateModel.fromJson(response.data!);
  }

  Future<CommunityLikeStateModel> unlikePost(String postId) async {
    final response = await _dio.delete<Map<String, dynamic>>('/api/posts/$postId/likes');
    return CommunityLikeStateModel.fromJson(response.data!);
  }

  Future<PagedCommunityCommentsModel> getComments({required String postId, int page = 1, int pageSize = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/posts/$postId/comments',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PagedCommunityCommentsModel.fromJson(response.data!);
  }

  Future<CommunityCommentModel> createComment({required String postId, required String content}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/posts/$postId/comments',
      data: {'content': content},
    );
    return CommunityCommentModel.fromJson(response.data!);
  }

  Future<void> deleteComment({required String postId, required String commentId}) async {
    await _dio.delete<void>('/api/posts/$postId/comments/$commentId');
  }
}
