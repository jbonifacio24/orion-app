import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:motohub/features/chat/data/models/chat_models.dart';
import 'package:motohub/features/chat/data/repositories/chat_repository_impl.dart';

void main() {
  test('repository maps datasource failures through ErrorMapper', () async {
    final repository = ChatRepositoryImpl(_FailingDataSource());

    expect(
      () => repository.getConversations(),
      throwsA(isA<NetworkFailure>()),
    );
  });
}

class _FailingDataSource extends ChatRestDataSource {
  _FailingDataSource() : super(Dio());

  @override
  Future<List<ConversationModel>> getConversations() => Future.error(
        DioException(requestOptions: RequestOptions(path: ''), type: DioExceptionType.connectionError),
      );
}
