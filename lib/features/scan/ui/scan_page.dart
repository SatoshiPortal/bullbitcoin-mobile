import 'dart:io';

import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/scan/presentation/scan_cubit.dart';
import 'package:bb_mobile/features/scan/presentation/scan_state.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Callback for when a payment request is detected from a QR code
typedef OnScannedPaymentRequestCallback =
    void Function((String, PaymentRequest?) data);

class FullScreenScanner extends StatefulWidget {
  final OnScannedPaymentRequestCallback onScannedPaymentRequest;
  final bool isModal;

  const FullScreenScanner({
    super.key,
    required this.onScannedPaymentRequest,
    this.isModal = false,
  });

  @override
  State<FullScreenScanner> createState() => _FullScreenScannerState();
}

class _FullScreenScannerState extends State<FullScreenScanner> {
  CameraController? _controller;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _controller = CameraController(
      backCamera,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    await _controller?.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );

    return BlocProvider(
      create: (_) => ScanCubit(controller: _controller!)..openCamera(),
      child: BlocListener<ScanCubit, ScanState?>(
        listenWhen:
            (previous, current) =>
                previous?.data.$1 != current?.data.$1 ||
                previous?.data.$2 != current?.data.$2,
        listener: (context, state) {
          if (state != null &&
              state.data.$1.isNotEmpty &&
              state.data.$2 != null) {
            widget.onScannedPaymentRequest.call(state.data);

            if (context.mounted) context.pop();
          }
        },
        child: BlocBuilder<ScanCubit, ScanState>(
          builder: (context, state) {
            return Scaffold(
              backgroundColor: context.colour.secondaryFixedDim,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
                  if (state.data.$1.isNotEmpty)
                    Positioned(
                      bottom: MediaQuery.of(context).size.height * 0.25,
                      left: 24,
                      right: 24,
                      child: BBButton.big(
                        iconData: Icons.check_circle,
                        textStyle: context.font.labelMedium,
                        textColor: context.colour.onPrimary,
                        onPressed: () {},
                        label:
                            state.data.$1.length > 30
                                ? '${state.data.$1.substring(0, 10)}…${state.data.$1.substring(state.data.$1.length - 10)}'
                                : state.data.$1,
                        bgColor: Colors.transparent,
                      ),
                    ),
                  if (state.isCollectingBbqr && state.bbqrOptions != null)
                    Positioned(
                      top: 60,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              'BBQR ${state.bbqr.keys.length}/${state.bbqrOptions!.total}',
                              style: context.font.labelMedium?.copyWith(
                                color: context.colour.onPrimary,
                              ),
                            ),
                            CircularProgressIndicator(
                              value:
                                  state.bbqr.keys.length /
                                  state.bbqrOptions!.total,
                              strokeWidth: 6,
                              backgroundColor: context.colour.onPrimary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isSuperuser && kDebugMode)
                    Positioned(
                      bottom: 150,
                      right: 0,
                      left: 0,
                      child: BBButton.big(
                        iconData:
                            state.isCollectingBbqr
                                ? Icons.check_box
                                : Icons.disabled_by_default,
                        textStyle: context.font.labelMedium,
                        textColor:
                            state.isCollectingBbqr ? Colors.green : Colors.red,
                        onPressed: context.read<ScanCubit>().switchBbqr,
                        label: 'BBQR',
                        bgColor: Colors.transparent,
                      ),
                    ),

                  Positioned(
                    bottom: MediaQuery.of(context).size.height * 0.02,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: IconButton(
                        onPressed: () {
                          if (context.mounted) context.pop();
                        },
                        icon: Icon(
                          CupertinoIcons.xmark_circle,
                          color: context.colour.onPrimary,
                          size: widget.isModal ? 64 : 56,
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
    );
  }
}
