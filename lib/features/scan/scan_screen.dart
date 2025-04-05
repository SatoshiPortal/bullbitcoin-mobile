import 'dart:async';
import 'package:bb_mobile/core/wallet/domain/entity/payment_request.dart';
import 'package:bb_mobile/features/scan/bbqr_service.dart';
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
  bool _isScanning = false;
  String data = '';
  String request = '';
  BbqrOptions? _bbqrOptions;
  Map<int, String> _bbqr = {};

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

  Future<void> tryDecodeBBQR() async {
    if (BbqrService.isValid(data)) {
      final options = BbqrService.decodeOptions(data);
      _bbqrOptions = options;

      if (options.total < _bbqr.length) _bbqr = {}; // reset another bbqr

      _bbqr[options.share] = data;

      if (_bbqrOptions!.total == _bbqr.length) {
        final bbqrSorted = _bbqr.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        final join = StringBuffer();
        for (final share in bbqrSorted) {
          join.write(share.value.substring(6));
        }

        debugPrint(join.toString()); // TODO: pass it to the bbqr lib
      }
    }
  }

  Future<void> tryPaymentRequest() async {
    try {
      final paymentRequest = await PaymentRequest.parse(data);
      request = paymentRequest.type.name;
    } catch (_) {}
  }

  Future<void> _startScanning() async {
    await _controller.startImageStream((CameraImage image) async {
      try {
        // Extract Y (brightness) plane (first plane in YUV420 format)
        final yPlaneBytes = image.planes[0].bytes;

        final qrText = ScanService.decode(
          yPlaneBytes,
          image.width,
          image.height,
        );
        data = qrText;

        await tryDecodeBBQR();

        await tryPaymentRequest();

        setState(() {});
      } catch (_) {} // Do nothing if nothing is decoded
    });

    setState(() => _isScanning = true);
  }

  Future<void> _stopScanning() async {
    await _controller.stopImageStream();
    data = '';
    _bbqrOptions = null;
    request = '';
    setState(() => _isScanning = false);
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
                        onLongPress: () {
                          Clipboard.setData(ClipboardData(text: data));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Copied to clipboard")),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors
                              .black54, // Background to make text readable
                          child: Column(
                            children: [
                              if (_bbqrOptions == null)
                                Text(
                                  request,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              Text(
                                data.length > 50
                                    ? '${data.substring(0, 20)}...${data.substring(data.length - 20)}'
                                    : data,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
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
                        onPressed: _isScanning ? _stopScanning : _startScanning,
                        child: Text(
                          _isScanning ? "Stop Scanning" : "Start Scanning",
                        ),
                      ),
                    ),
                  ),
                  if (_bbqrOptions != null)
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.black54,
                          child: Column(
                            children: [
                              Text(
                                'BBQR ${_bbqr.keys.length}/${_bbqrOptions!.total}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              CircularProgressIndicator(
                                value: _bbqr.keys.length / _bbqrOptions!.total,
                                strokeWidth: 6,
                                backgroundColor: Colors.grey.shade300,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
