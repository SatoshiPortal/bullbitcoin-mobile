import 'dart:async';
import 'package:bb_mobile/core/wallet/domain/entity/payment_request.dart';
import 'package:bb_mobile/features/scan/scan_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late CameraController _controller;
  List<CameraDescription> _cameras = [];
  bool _isStream = false;
  String data = '';

  Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    _cameras = await availableCameras();

    _controller = CameraController(_cameras.first, ResolutionPreset.max);

    _controller.initialize().then((_) {}).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            // Handle access errors here.
            break;
          default:
            // Handle other errors here.
            break;
        }
      }
    });

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startStream() async {
    await _controller.startImageStream((CameraImage image) {
      try {
        // Extract Y (brightness) plane (first plane in YUV420 format)
        final yPlaneBytes = image.planes[0].bytes;

        final qrText = ScanService.decode(
          yPlaneBytes,
          image.width,
          image.height,
        );
        data = qrText;
        setState(() {});
      } catch (_) {} // Do nothing if nothing is decoded
    });

    setState(() => _isStream = true);
  }

  Future<void> _stopStream() async {
    await _controller.stopImageStream();
    setState(() => _isStream = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Scanner")),
        body: _cameras.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(child: CameraPreview(_controller)),
                  if (data.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 100, // Adjust as needed
                      child: GestureDetector(
                        onLongPress: () async {
                          Clipboard.setData(ClipboardData(text: data));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Copied to clipboard")),
                          );

                          // TODO: Example to parse the data in order to find out the payment type
                          try {
                            final request = await PaymentRequest.parse(data);
                            debugPrint("REQUEST: ${request.runtimeType}");
                          } catch (_) {}
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors
                              .black54, // Background to make text readable
                          child: Text(
                            data.length > 50
                                ? '${data.substring(0, 20)}...${data.substring(data.length - 20)}'
                                : data,
                            style: const TextStyle(
                              color: Colors
                                  .white, // Make text visible over camera preview
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ElevatedButton(
                        onPressed: _isStream ? _stopStream : _startStream,
                        child: Text(_isStream ? "Stop Stream" : "Start Stream"),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
