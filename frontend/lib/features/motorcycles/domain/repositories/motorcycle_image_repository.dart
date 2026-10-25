import '../entities/motorcycle_image.dart';
import '../entities/motorcycle_image_upload.dart';

abstract interface class MotorcycleImageRepository {
  Future<MotorcycleImage> uploadImage(String id, MotorcycleImageUpload image);
  Future<void> deleteImage(String id, String imageId);
}
