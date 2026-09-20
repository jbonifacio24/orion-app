import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/network/media_url_resolver.dart';
import 'package:motohub/features/marketplace/data/datasources/marketplace_data_source.dart';
import 'package:motohub/features/marketplace/domain/entities/product_image_upload.dart';

void main() {
  test('resolves relative media paths against the host without the api path', () {
    expect(MediaUrlResolver.resolve('/media/x.jpg'), 'http://10.0.2.2:5001/media/x.jpg');
  });

  test('preserves absolute media URLs', () {
    expect(MediaUrlResolver.resolve('https://cdn.example.com/image.jpg'), 'https://cdn.example.com/image.jpg');
  });

  test('builds multipart upload with the exact file field and bytes', () async {
    final adapter = _CaptureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'))..httpClientAdapter = adapter;
    final source = MarketplaceDataSource(dio);
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    final image = await source.uploadProductImage('product-1', ProductImageUpload(bytes: bytes, fileName: 'photo.jpg', sizeBytes: bytes.length));

    expect(image.id, 'image-1');
    expect(adapter.path, '/api/products/product-1/images');
    expect(adapter.method, 'POST');
    expect(adapter.fileField, isTrue);
    expect(adapter.fileName, 'photo.jpg');
    expect(adapter.fileBytes, bytes);
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  String? path;
  String? method;
  bool fileField = false;
  String? fileName;
  Uint8List? fileBytes;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    path = options.path;
    method = options.method;
    if (requestStream != null) {
      final requestBytes = await requestStream.fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
      final requestBody = String.fromCharCodes(requestBytes);
      if (requestBody.contains('name="file"')) {
        fileField = true;
      }
      final filenameMatch = RegExp(r'filename="([^"]+)"').firstMatch(requestBody);
      fileName = filenameMatch?.group(1);
      final marker = requestBytes.indexOf(13);
      final content = requestBody.contains('\r\n\r\n') ? requestBody.split('\r\n\r\n').last.split('\r\n').first : '';
      if (content.isNotEmpty) {
        fileBytes = Uint8List.fromList(content.codeUnits);
      } else if (marker >= 0) {
        fileBytes = Uint8List.fromList(requestBytes.sublist(marker));
      }
    }
    if (fileField && fileName == null) {
      final data = options.data;
      if (data is FormData) {
        final file = data.files.singleWhere((entry) => entry.key == 'file').value;
        fileName = file.filename;
      }
    }
    return ResponseBody(Stream.value(Uint8List.fromList(utf8.encode(jsonEncode({'id': 'image-1', 'url': '/media/image-1.jpg', 'thumbnailUrl': null, 'displayOrder': 0, 'isPrimary': true})))), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}