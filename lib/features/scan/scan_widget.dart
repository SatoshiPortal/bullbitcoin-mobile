import 'package:bb_mobile/features/scan/presentation/scan_cubit.dart';
import 'package:bb_mobile/features/scan/presentation/scan_state.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_controller != null && _cameraInitialized) ...[
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 16,
                      ),
                      child: BlocProvider(
                        create: (_) {
                          final cubit = ScanCubit(controller: _controller!);
                          // Start scanning automatically when camera preview is shown
                          cubit.startScanning();
                          return cubit;
                        },
                        child: BlocBuilder<ScanCubit, ScanState>(
                          builder: (context, state) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(_controller!),
                                  if (state.data.isNotEmpty)
                                    Positioned(
                                      bottom: 60,
                                      left: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () {
                                          final data = state.data;
                                          Clipboard.setData(
                                            ClipboardData(text: data),
                                          );
                                          debugPrint(
                                            'Copied to clipboard: $data',
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          color: Colors.black54,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: BBText(
                                                  state.data.length > 50
                                                      ? '${state.data.substring(0, 20)}...${state.data.substring(state.data.length - 20)}'
                                                      : state.data,
                                                  color:
                                                      context.colour.onPrimary,
                                                  style:
                                                      context.font.labelSmall,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.copy,
                                                size: 16,
                                                color: context.colour.onPrimary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
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
