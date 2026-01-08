import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/urqr/urqr.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _cameraPermissionGranted = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() => _cameraPermissionGranted = true);
      return;
    }
    if (status.isPermanentlyDenied) {
      setState(() => _permissionDenied = true);
      return;
    }
    final requestedStatus = await Permission.camera.request();
    if (requestedStatus.isGranted) {
      setState(() => _cameraPermissionGranted = true);
    } else {
      setState(() => _permissionDenied = true);
    }
  }

  @override
  void dispose() {
    super.dispose();
    zx.stopCameraProcessing();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraPermissionGranted) {
      if (_permissionDenied) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: .center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 64,
                  color: context.appColors.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Camera permission is required to scan QR codes',
                  style: context.font.bodyLarge,
                  textAlign: .center,
                ),
                const SizedBox(height: 16),
                BBButton.big(
                  label: 'Open Settings',
                  onPressed: () => openAppSettings(),
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: CircularProgressIndicator(
          color: context.appColors.primary,
        ),
      );
    }

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
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _progressText,
                style: TextStyle(
                  color: context.appColors.onSecondary,
                  fontSize: 14,
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
