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
}
