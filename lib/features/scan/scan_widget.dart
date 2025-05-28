import 'dart:io';

import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/scan/presentation/scan_cubit.dart';
import 'package:bb_mobile/features/scan/presentation/scan_state.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart'
    show SettingsCubit;
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// Callback for when a payment request is detected from a QR code
typedef OnScannedPaymentRequestCallback =
    void Function((String, PaymentRequest?) data);

class ScanWidget extends StatefulWidget {
  /// Callback function that will be called when a payment request is detected
  final OnScannedPaymentRequestCallback? onScannedPaymentRequest;

  const ScanWidget({super.key, this.onScannedPaymentRequest});

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
        setState(() => _error = 'No cameras available.');
        return;
      }

      // Find the back camera
      final backCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      //  medium resolution for better performance and focusing
      final resolution =
          Platform.isIOS ? ResolutionPreset.medium : ResolutionPreset.max;

      _controller = CameraController(
        backCamera,
        resolution,
        enableAudio: false,
        imageFormatGroup:
            Platform.isIOS
                ? ImageFormatGroup.bgra8888
                : ImageFormatGroup.yuv420,
      );

      await _controller?.initialize();

      if (mounted) setState(() => _cameraInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );

    return ColoredBox(
      color: context.colour.secondaryFixedDim,
      child: SafeArea(
        child: Column(
          children: [
            if (_controller != null && _cameraInitialized) ...[
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  child: BlocProvider(
                    create: (_) {
                      final cubit = ScanCubit(controller: _controller!);
                      // Start scanning automatically when camera preview is shown
                      cubit.startScanning();
                      return cubit;
                    },
                    child: BlocConsumer<ScanCubit, ScanState>(
                      listener: (context, state) {
                        // Auto-trigger callback when address is detected
                        if (state.data.$1.isNotEmpty && state.data.$2 != null) {
                          widget.onScannedPaymentRequest?.call(state.data);
                        }
                      },
                      builder: (context, state) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(_controller!),
                              if (state.data.$1.isNotEmpty)
                                Positioned(
                                  bottom: 60,
                                  left: 0,
                                  right: 0,
                                  child: BBButton.big(
                                    iconData: Icons.check_circle,
                                    textStyle: context.font.labelSmall,
                                    textColor: context.colour.onPrimary,
                                    onPressed: () {},
                                    label:
                                        state.data.$1.length > 30
                                            ? '${state.data.$1.substring(0, 10)}…${state.data.$1.substring(state.data.$1.length - 10)}'
                                            : state.data.$1,
                                    bgColor: Colors.transparent,
                                  ),
                                ),
                              if (state.isCollectingBbqr &&
                                  state.bbqrOptions != null)
                                Positioned(
                                  top: 60,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          'BBQR ${state.bbqr.keys.length}/${state.bbqrOptions!.total}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                          ),
                                        ),
                                        CircularProgressIndicator(
                                          value:
                                              state.bbqr.keys.length /
                                              state.bbqrOptions!.total,
                                          strokeWidth: 6,
                                          backgroundColor: Colors.grey.shade300,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (isSuperuser && kDebugMode)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  left: 0,
                                  child: BBButton.big(
                                    iconData:
                                        state.isCollectingBbqr
                                            ? Icons.check_box
                                            : Icons.disabled_by_default,
                                    textStyle: context.font.labelSmall,
                                    textColor:
                                        state.isCollectingBbqr
                                            ? Colors.green
                                            : Colors.red,
                                    onPressed:
                                        context.read<ScanCubit>().switchBbqr,
                                    label: 'BBQR',
                                    bgColor: Colors.transparent,
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
              // Add some top spacing
              const Gap(30),
              // QR placeholder with fixed dimensions
              Image.asset(Assets.qRPlaceholder.path, height: 221, width: 221),
              const Gap(24),
              // Instruction text with padding
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
              const Gap(24),
              // Error message if any
              if (_error.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: BBText(
                    _error,
                    color: context.colour.error,
                    style: context.font.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const Gap(16),
              ],
              // Button to open camera
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 52),
                child: BBButton.small(
                  outlined: true,
                  onPressed: () {
                    if (!_cameraInitialized) {
                      _initCamera();
                    }
                  },
                  label: 'Open the Camera',
                  bgColor: Colors.transparent,
                  borderColor: context.colour.surfaceContainer,
                  textColor: context.colour.secondary,
                ),
              ),
              // Flexible space to push content up
              const Spacer(),
            ],
          ],
        ),
      ),
    );
  }
}
