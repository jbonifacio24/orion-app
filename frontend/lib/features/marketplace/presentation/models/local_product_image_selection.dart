import '../../domain/entities/product_image_upload.dart';

enum LocalProductImageStatus { pending, uploading, failed }

class LocalProductImageSelection {
  const LocalProductImageSelection({required this.id, required this.upload, this.status = LocalProductImageStatus.pending, this.failureMessage});

  final String id;
  final ProductImageUpload upload;
  final LocalProductImageStatus status;
  final String? failureMessage;

  LocalProductImageSelection copyWith({LocalProductImageStatus? status, String? failureMessage, bool clearFailure = false}) => LocalProductImageSelection(
        id: id,
        upload: upload,
        status: status ?? this.status,
        failureMessage: clearFailure ? null : failureMessage ?? this.failureMessage,
      );
}