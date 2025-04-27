import 'package:bb_mobile/features/scan/presentation/scan_cubit.dart';
import 'package:bb_mobile/features/scan/presentation/scan_state.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ScanWidget extends StatefulWidget {
  const ScanWidget({super.key});

  @override
  State<ScanWidget> createState() => _ScanWidgetState();
}

class _ScanWidgetState extends State<ScanWidget> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  String _error = '';
  bool _cameraInitialized = false;

  Future<void> _initCamera() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _error = 'No cameras available.';
      } else {
        _controller = CameraController(
          _cameras.first,
          ResolutionPreset.max,
          enableAudio: false,
        );
        await _controller?.initialize();
        _cameraInitialized = true;
      }
    } catch (e) {
      _error = e.toString();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.secondaryFixedDim,
      body: Stack(
        children: [
          // const _BG(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Spacer(),
                Image.asset(
                  Assets.qRPlaceholder.path,
                  height: 172,
                  width: 172,
                ),
                const Gap(36),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: BBText(
                    'Scan any Bitcoin or Lightning QR code to pay with bitcoin.',
                    style: context.font.labelSmall,
                    color: context.colour.secondary,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error.isNotEmpty) ...[
                        BBText(
                          _error,
                          color: context.colour.error,
                          style: context.font.labelSmall,
                          textAlign: TextAlign.center,
                        ),
                        const Gap(16),
                      ],
                      BBButton.small(
                        onPressed: _cameraInitialized
                            ? () {
                                if (_controller != null) {
                                  _controller!.dispose();
                                  _cameraInitialized = false;
                                }
                              }
                            : () async {
                                await _initCamera();
                              },
                        label: _cameraInitialized
                            ? 'Camera Initialized'
                            : 'Open Camera',
                        bgColor: context.colour.onPrimary,
                        textColor: context.colour.secondary,
                        width: 12,
                      ),
                      if (_controller != null && _cameraInitialized)
                        SizedBox(
                          height: 300,
                          width: 300,
                          child: BlocProvider(
                            create: (_) => ScanCubit(controller: _controller!),
                            child: BlocBuilder<ScanCubit, ScanState>(
                              builder: (context, state) {
                                return Stack(
                                  children: [
                                    Positioned.fill(
                                      child: CameraPreview(_controller!),
                                    ),
                                    if (state.data.isNotEmpty)
                                      Positioned(
                                        bottom: 20,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          color: Colors.black54,
                                          child: BBText(
                                            state.data.length > 50
                                                ? '${state.data.substring(0, 20)}...${state.data.substring(state.data.length - 20)}'
                                                : state.data,
                                            color: context.colour.onPrimary,
                                            style: context.font.labelSmall,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 60,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: BBButton.small(
                                          onPressed: () {
                                            final cubit =
                                                context.read<ScanCubit>();
                                            state.isStreaming
                                                ? cubit.stopScanning()
                                                : cubit.startScanning();
                                          },
                                          label: state.isStreaming
                                              ? 'Stop Scan'
                                              : 'Start Scan',
                                          bgColor: context.colour.onPrimary,
                                          textColor: context.colour.secondary,
                                          width: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
