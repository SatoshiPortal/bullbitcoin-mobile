import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class ScannerWidget extends StatefulWidget {
  final void Function(String data) onScanned;
  final ResolutionPreset resolution;
  final Duration scanDelay;

  const ScannerWidget({
    super.key,
    required this.onScanned,
    this.resolution = ResolutionPreset.high,
    this.scanDelay = const Duration(milliseconds: 1000),
  });

  @override
  State<ScannerWidget> createState() => _ScannerState();
}

class _ScannerState extends State<ScannerWidget> {
  @override
  void dispose() {
    super.dispose();
    zx.stopCameraProcessing();
  }

  @override
  Widget build(BuildContext context) {
    return ReaderWidget(
      scanDelay: widget.scanDelay,
      scanDelaySuccess: widget.scanDelay,
      onScan: (result) {
        if (!mounted) return;

        if (result.isValid && result.text != null && result.text!.isNotEmpty) {
          widget.onScanned(result.text!);
        }
      },
      resolution: widget.resolution,
      showGallery: false, // doesn't work well
    );
  }
}
