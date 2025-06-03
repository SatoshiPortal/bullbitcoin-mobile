import 'dart:io';

import 'package:bb_mobile/features/experimental/scanner/scanner_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class ScannerWidget extends StatefulWidget {
  final void Function(String data) onScanned;
  final bool isModal;
  final ResolutionPreset resolution;
  final bool enableAudio;

  const ScannerWidget({
    super.key,
    required this.onScanned,
    this.isModal = false,
    this.resolution = ResolutionPreset.low,
    this.enableAudio = false,
  });

  @override
  State<ScannerWidget> createState() => _ScannerState();
}

class _ScannerState extends State<ScannerWidget> {
  CameraController? _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();

    final camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      widget.resolution,
      enableAudio: widget.enableAudio,
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );

    await _controller?.initialize();

    if (mounted) _startImageStream();

    setState(() {});
  }

  void _startImageStream() {
    if (Platform.isIOS) {
      Future.delayed(
        const Duration(milliseconds: 100),
        () => _startProcessing(),
      );
    } else {
      _startProcessing();
    }
  }

  void _startProcessing() {
    _controller?.startImageStream((CameraImage image) {
      if (_isProcessing) return;
      setState(() => _isProcessing = true);

      try {
        final imageBytes = image.planes[0].bytes;
        final qr = ScannerService.decode(imageBytes, image.width, image.height);

        widget.onScanned(qr);
      } catch (e) {
        // debugPrint('Error decoding QR: $e');
      }

      setState(() => _isProcessing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: CameraPreview(_controller!),
    );
  }
}
