import 'dart:typed_data';

class ImageToCell {
  final int row;
  final int col;
  final String imageId;
  final String imageTarget;
  final Uint8List bytes;
  final String format;
  final int? width;
  final int? height;

  const ImageToCell({
    required this.row,
    required this.col,
    required this.imageId,
    required this.imageTarget,
    required this.bytes,
    required this.format,
    required this.width,
    required this.height,
  });
}
