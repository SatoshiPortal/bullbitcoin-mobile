import 'dart:typed_data';

import 'package:zxing2/qrcode.dart';

class ScanService {
  static String decode(List<int> bytes, int width, int height) {
    // Convert Y values to Int32List (grayscale, ARGB format)
    final rgbBytes = Int32List(width * height);

    // Get the Y value (brightness) and convert it to grayscale ARGB
    for (int i = 0; i < width * height; i++) {
      // Ensure it's within 0-255 range
      final yValue = bytes[i] & 0xFF;
      // ARGB format
      rgbBytes[i] = (0xFF << 24) | (yValue << 16) | (yValue << 8) | yValue;
    }

    // Create LuminanceSource from Int32List
    final source = RGBLuminanceSource(width, height, rgbBytes);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final reader = QRCodeReader();

    return reader.decode(bitmap).text;
  }
}
