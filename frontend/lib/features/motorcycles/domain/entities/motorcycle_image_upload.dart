import 'dart:typed_data';

class MotorcycleImageUpload {
  const MotorcycleImageUpload({required this.bytes, required this.fileName, required this.sizeBytes});

  final Uint8List bytes;
  final String fileName;
  final int sizeBytes;
}
