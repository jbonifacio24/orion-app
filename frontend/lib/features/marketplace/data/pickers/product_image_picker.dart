import 'package:file_picker/file_picker.dart';

import '../../domain/entities/product_image_upload.dart';
import '../../domain/services/product_image_picker.dart';

class FilePickerProductImagePicker implements IProductImagePicker {
  const FilePickerProductImagePicker();

  @override
  Future<List<ProductImageUpload>> pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null) return const [];
    return result.files
        .where((file) => file.bytes != null)
        .map((file) => ProductImageUpload(bytes: file.bytes!, fileName: file.name, sizeBytes: file.size))
        .toList(growable: false);
  }
}