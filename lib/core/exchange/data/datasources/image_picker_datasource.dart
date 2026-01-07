import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class PickedImage {
  final String fileName;
  final Uint8List bytes;

  const PickedImage({required this.fileName, required this.bytes});
}

class ImagePickerDatasource {
  final ImagePicker _imagePicker;

  ImagePickerDatasource() : _imagePicker = ImagePicker();

  Future<List<PickedImage>> pickMultipleImages() async {
    final images = await _imagePicker.pickMultiImage();

    if (images.isEmpty) {
      return [];
    }

    final pickedImages = <PickedImage>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      pickedImages.add(PickedImage(fileName: image.name, bytes: bytes));
    }

    return pickedImages;
  }
}

