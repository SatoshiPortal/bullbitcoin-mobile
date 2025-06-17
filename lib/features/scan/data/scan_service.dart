import 'dart:io';
import 'dart:typed_data';

import 'package:zxing2/qrcode.dart';

class ScanService {
  // Track if we're currently processing to avoid excessive CPU usage
  static bool _isProcessing = false;

  static String decode(List<int> bytes, int width, int height) {
    if (_isProcessing) throw Exception('Already processing…');

    _isProcessing = true;
    try {
      // Handle iOS and Android differently
      if (Platform.isIOS) {
        return _decodeIOS(bytes, width, height);
      } else {
        return _decodeAndroid(bytes, width, height);
      }
    } catch (e) {
      rethrow;
    } finally {
      _isProcessing = false;
    }
  }

  // Decode for iOS - handles BGRA format
  static String _decodeIOS(List<int> bytes, int width, int height) {
    // Convert BGRA values to Int32List for QR processing
    final rgbBytes = Int32List(width * height);

    // iOS uses BGRA8888 format, 4 bytes per pixel
    const pixelStride = 4;

    // Get the brightness from BGRA
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = y * width * pixelStride + x * pixelStride;
        // Skip if out of bounds
        if (idx + 2 >= bytes.length) continue;

        // Get RGB values - convert BGRA to luminance
        final b = bytes[idx] & 0xFF;
        final g = bytes[idx + 1] & 0xFF;
        final r = bytes[idx + 2] & 0xFF;

        // Calculate luminance - standard formula for converting RGB to grayscale
        final luminance = ((r * 0.299) + (g * 0.587) + (b * 0.114)).toInt();

        // Set the pixel value in the destination array
        final destIdx = y * width + x;
        if (destIdx < rgbBytes.length) {
          rgbBytes[destIdx] =
              (0xFF << 24) | (luminance << 16) | (luminance << 8) | luminance;
        }
      }
    }

    return _attemptDecode(rgbBytes, width, height);
  }

  // Decode for Android - handles YUV format
  static String _decodeAndroid(List<int> bytes, int width, int height) {
    // Convert Y values to Int32List (grayscale, ARGB format)
    final rgbBytes = Int32List(width * height);

    // Get the Y value (brightness) and convert it to grayscale ARGB
    for (int i = 0; i < width * height && i < bytes.length; i++) {
      // Ensure it's within 0-255 range
      final yValue = bytes[i] & 0xFF;
      // ARGB format
      rgbBytes[i] = (0xFF << 24) | (yValue << 16) | (yValue << 8) | yValue;
    }

    return _attemptDecode(rgbBytes, width, height);
  }

  // Try both binarizers for better results in different lighting conditions
  static String _attemptDecode(Int32List rgbBytes, int width, int height) {
    // Create LuminanceSource from Int32List
    final source = RGBLuminanceSource(width, height, rgbBytes);
    final reader = QRCodeReader();

    try {
      // First try with HybridBinarizer
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      return reader.decode(bitmap).text;
    } catch (_) {
      try {
        // If that fails, try with GlobalHistogramBinarizer
        final bitmap2 = BinaryBitmap(GlobalHistogramBinarizer(source));
        return reader.decode(bitmap2).text;
      } catch (_) {
        throw Exception('HybridBinarizer and GlobalHistogramBinarizer failed');
      }
    }
  }
}
