import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_parser/http_parser.dart';
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

  for (final attachment in [
    (name: 'camera.jpg', type: MediaType('image', 'jpeg')),
    (name: 'voice.wav', type: MediaType('audio', 'wav')),
  ]) {
    test('attachment ${attachment.name} sends its allowed content type', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://motohub.test'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        final form = options.data as FormData;
        expect(form.files.single.value.contentType, attachment.type);
        handler.reject(DioException(requestOptions: options));
      }));
      final dataSource = ChatRestDataSource(dio);

      await expectLater(
        dataSource.sendAttachment(
          conversationId: 'conversation-id',
          file: PlatformFile(name: attachment.name, size: 4, bytes: Uint8List.fromList([1, 2, 3, 4])),
        ),
        throwsA(isA<DioException>()),
      );
    });
  }
}

class _FailingDataSource extends ChatRestDataSource {
  _FailingDataSource() : super(Dio());

  @override
  Future<List<ConversationModel>> getConversations() => Future.error(
        DioException(requestOptions: RequestOptions(path: ''), type: DioExceptionType.connectionError),
      );
}
