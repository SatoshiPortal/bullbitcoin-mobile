import 'package:bull_ui/app_theme.dart';
import 'package:signers/signers.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_ui/bull_ui.dart' show BullShapesX, BullTypographyX;
import 'package:material_ui/material_ui.dart';
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
                color: context.appColors.secondary,
                borderRadius: BorderRadius.circular(context.bullShapes.card),
              ),
              child: Text(
                _progressText,
                style: context.bullType.label.copyWith(
                  fontWeight: FontWeight.w400,
                  color: context.appColors.onSecondary,
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
          _progressText = context.loc.scanningProgressLabel('$percent');
        } else {
          _progressText = context.loc.urProgressLabel(
            '${_urReader.processedParts}',
          );
        }
      });

      if (_urReader.isComplete) {
        if (_urReader.decoded != null) {
          setState(() => _progressText = context.loc.scanningCompletedMessage);
          final decoded = _urReader.decoded!.toString();
          _urReader.reset();
          widget.onScanned(decoded);
        } else {
          setState(() => _progressText = context.loc.urDecodingFailedMessage);
        }
      }
    } catch (e) {
      log.severe(
        message: 'UR processing failed',
        error: e,
        trace: StackTrace.current,
      );
      _urReader.reset();
      setState(() => _progressText = context.loc.urProcessingFailedMessage);
    }
  }
}
