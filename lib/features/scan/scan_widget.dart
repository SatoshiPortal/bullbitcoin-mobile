import 'package:bb_mobile/features/scan/presentation/scan_cubit.dart';
import 'package:bb_mobile/features/scan/presentation/scan_state.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ScanWidget extends StatefulWidget {
  const ScanWidget({super.key});

  @override
  State<ScanWidget> createState() => _ScanWidgetState();
}

class _ScanWidgetState extends State<ScanWidget> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    WidgetsFlutterBinding.ensureInitialized();
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      _error = 'no cameras available';
      setState(() {});
    } else {
      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.max,
        enableAudio: false,
      );
      await _controller?.initialize();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error.isNotEmpty) return Center(child: Text(_error));

    if (_controller != null) {
      return BlocProvider(
        create: (_) => ScanCubit(controller: _controller!),
        child: BlocBuilder<ScanCubit, ScanState>(
          builder: (context, state) {
            return Stack(
              children: [
                Positioned.fill(child: CameraPreview(_controller!)),

                if (state.data.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 100,
                    child: GestureDetector(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: state.data));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Copied to clipboard",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.colour.onSurface),
                            ),
                            backgroundColor: context.colour.surface,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.black54,
                        child: Column(
                          children: [
                            if (state.paymentRequest != null)
                              Text(
                                '${state.paymentRequest!.name} on ${state.paymentRequest!.isTestnet ? 'testnet' : 'mainnet'}',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: context.colour.primary),
                              ),
                            Text(
                              state.data.length > 50
                                  ? '${state.data.substring(0, 20)}...${state.data.substring(state.data.length - 20)}'
                                  : state.data,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.colour.onPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Toggle Stream Button
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        final cubit = context.read<ScanCubit>();
                        state.isStreaming
                            ? cubit.stopScanning()
                            : cubit.startScanning();
                      },
                      child:
                          Text(state.isStreaming ? "Stop Scan" : "Start Scan"),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }
}
