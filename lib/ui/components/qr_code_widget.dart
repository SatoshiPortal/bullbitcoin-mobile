import 'dart:typed_data';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image/image.dart' as imglib;

class QrCodeWidget extends StatelessWidget {
  final String data;
  final int width;
  final int height;
  final int margin;
  final EccLevel eccLevel;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final int format;

  const QrCodeWidget({
    super.key,
    required this.data,
    this.width = 250,
    this.height = 250,
    this.margin = 0,
    this.eccLevel = EccLevel.low,
    this.backgroundColor,
    this.foregroundColor,
    this.format = Format.qrCode,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _generateQrCode(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: width.toDouble(),
            height: height.toDouble(),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return SizedBox(
            width: width.toDouble(),
            height: height.toDouble(),
            child: const Center(child: Icon(Icons.error, color: Colors.red)),
          );
        }

        return Image.memory(
          snapshot.data!,
          width: width.toDouble(),
          height: height.toDouble(),
          fit: BoxFit.contain,
        );
      },
    );
  }

  Future<Uint8List?> _generateQrCode() async {
    try {
      final result = zx.encodeBarcode(
        contents: data,
        params: EncodeParams(
          format: format,
          width: width,
          height: height,
          margin: margin,
          eccLevel: eccLevel,
        ),
      );

      if (result.isValid && result.data != null) {
        final img = imglib.Image.fromBytes(
          width: width,
          height: height,
          bytes: result.data!.buffer,
          numChannels: 1,
        );
        return imglib.encodePng(img);
      }
      return null;
    } catch (e) {
      log.warning('Failed to generate QR code');
      return null;
    }
  }
}
