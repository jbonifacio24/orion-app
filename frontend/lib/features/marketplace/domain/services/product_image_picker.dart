import '../entities/product_image_upload.dart';

abstract interface class IProductImagePicker {
  Future<List<ProductImageUpload>> pickImages();
}
