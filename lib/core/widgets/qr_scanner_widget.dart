import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/urqr/urqr.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class QrScannerWidget extends StatefulWidget {
  final void Function(String data) onScanned;
  final ResolutionPreset resolution;
  final Duration scanDelay;

  const QrScannerWidget({
    super.key,
    required this.onScanned,
    this.resolution = ResolutionPreset.high,
    this.scanDelay = const Duration(milliseconds: 1000),
  });

  @override
  State<QrScannerWidget> createState() => _ScannerState();
}

class _ScannerState extends State<QrScannerWidget> {
  final UrQrReader _urReader = UrQrReader();
  String _progressText = '';

  @override
  void dispose() {
    super.dispose();
    zx.stopCameraProcessing();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ReaderWidget(
          scanDelay: widget.scanDelay,
          scanDelaySuccess: widget.scanDelay,
          onScan: (result) {
            if (!mounted) return;

            if (result.isValid &&
                result.text != null &&
                result.text!.isNotEmpty) {
              _processQrData(result.text!);
            }
          },
          resolution: widget.resolution,
          showGallery: true,
          tryInverted: true,
        ),

        // UR Progress Display
        if (_progressText.isNotEmpty)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colour.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _progressText,
                style: TextStyle(
                  color: context.colour.onSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _processQrData(String data) {
    if (data.toLowerCase().startsWith('ur:')) {
      _processUrData(data);
    } else {
      widget.onScanned(data);
    }
  }

  void _processUrData(String data) {
    try {
      _urReader.receive(data);

      setState(() {
        if (_urReader.expectedParts != null) {
          final percent = (_urReader.progress * 100).toInt();
          _progressText = 'Scanning: $percent%';
        } else {
          _progressText = 'UR Progress: ${_urReader.processedParts} parts';
        }
      });

      if (_urReader.isComplete) {
        if (_urReader.decoded != null) {
          setState(() => _progressText = 'Scanning completed');
          widget.onScanned(_urReader.decoded!.toString());
        } else {
          setState(() => _progressText = 'UR decoding failed');
        }
      }
    } catch (e) {
      log.severe('UR processing failed $e');
      setState(() => _progressText = 'UR processing failed');
    }
  }
}
