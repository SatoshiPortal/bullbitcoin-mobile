import 'package:signers/signers.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullShapesX, BullThemeX, BullTypographyX;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'scanning_labels.dart';

class QrScannerWidget extends StatefulWidget {
  final void Function(String data) onScanned;
  final QrScanningLabels labels;
  final ResolutionPreset resolution;
  final Duration scanDelay;

  const QrScannerWidget({
    super.key,
    required this.onScanned,
    required this.labels,
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

            final text = result.text;
            if (result.isValid && text != null && text.isNotEmpty) {
              _processQrData(text);
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
                color: context.bull.secondary,
                borderRadius: BorderRadius.circular(context.bullShapes.card),
              ),
              child: Text(
                _progressText,
                style: context.bullType.label.copyWith(
                  fontWeight: FontWeight.w400,
                  color: context.bull.onSecondary,
                ),
                textAlign: .center,
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
          _progressText = widget.labels.scanningProgressLabel('$percent');
        } else {
          _progressText = widget.labels.urProgressLabel(
            '${_urReader.processedParts}',
          );
        }
      });

      if (_urReader.isComplete) {
        if (_urReader.decoded case final result?) {
          setState(
            () => _progressText = widget.labels.scanningCompletedMessage,
          );
          final decoded = result.toString();
          _urReader.reset();
          widget.onScanned(decoded);
        } else {
          setState(() => _progressText = widget.labels.urDecodingFailedMessage);
        }
      }
    } catch (e) {
      log.severe(
        message: 'UR processing failed',
        error: e.runtimeType,
        trace: StackTrace.current,
      );
      _urReader.reset();
      setState(() => _progressText = widget.labels.urProcessingFailedMessage);
    }
  }
}
