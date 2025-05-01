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
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: context.colour.secondaryFixedDim,
      body: Stack(
        children: [
          // const _BG(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_controller != null && _cameraInitialized) ...[
                  Container(
                    height:
                        size.height *
                        0.6, // Increased height to accommodate button
                    padding: const EdgeInsets.only(left: 16, right: 16),
                    child: BlocProvider(
                      create: (_) {
                        final cubit = ScanCubit(controller: _controller!);
                        // Start scanning automatically when camera preview is shown
                        cubit.startScanning();
                        return cubit;
                      },
                      child: BlocBuilder<ScanCubit, ScanState>(
                        builder: (context, state) {
                          return Stack(
                            fit:
                                StackFit
                                    .expand, // Added to ensure proper fitting
                            children: [
                              CameraPreview(
                                _controller!,
                              ), // Removed Positioned.fill
                              if (state.data.isNotEmpty)
                                Positioned(
                                  bottom:
                                      60, // Increased to avoid overlap with button
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
                              if (state.isStreaming)
                                Positioned(
                                  bottom: 16, // Added padding from bottom
                                  left: 16,
                                  right: 16,
                                  child: SizedBox(
                                    // Wrapped with SizedBox instead of Center
                                    width: double.infinity,
                                    child: BBButton.small(
                                      onPressed: () {
                                        context
                                            .read<ScanCubit>()
                                            .stopScanning();
                                      },
                                      label: 'Stop Scan',
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
                ] else ...[
                  const Gap(50),
                  Image.asset(
                    Assets.qRPlaceholder.path,
                    height: 221,
                    width: 221,
                  ),
                  const Gap(32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: BBText(
                      'Scan any Bitcoin or Lightning QR code to pay with bitcoin.',
                      style: context.font.bodyMedium,
                      color: context.colour.outlineVariant,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 52,
                      vertical: 32,
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
                          outlined: true,
                          onPressed:
                              _cameraInitialized
                                  ? () {
                                    if (_controller != null) {
                                      _controller!.dispose();
                                      _cameraInitialized = false;
                                    }
                                  }
                                  : () async {
                                    await _initCamera();
                                  },
                          label: 'Open the Camera',
                          bgColor: Colors.transparent,
                          borderColor: context.colour.surfaceContainer,
                          textColor: context.colour.secondary,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
