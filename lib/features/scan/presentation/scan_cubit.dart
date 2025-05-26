import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/scan/presentation/scan_state.dart';
import 'package:bb_mobile/features/scan/scan_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ScanCubit extends Cubit<ScanState> {
  final CameraController controller;
  bool _processingImage = false;

  ScanCubit({required this.controller}) : super(ScanState.initial());

  Future<void> startScanning() async {
    // Added delay for iOS to ensure camera is fully initialized
    if (Platform.isIOS) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    await controller.startImageStream((CameraImage image) async {
      if (_processingImage) return;

      _processingImage = true;
      try {
        final imageBytes = image.planes[0].bytes;

        final qrText = ScanService.decode(
          imageBytes,
          image.width,
          image.height,
        );

        if (qrText.isNotEmpty && qrText != state.data.$1) {
          PaymentRequest? pr;
          try {
            pr = await PaymentRequest.parse(qrText);
          } catch (e) {
            debugPrint('Error: $e, parsing payment request: $qrText');
          }

          emit(state.copyWith(data: (qrText, pr)));
        }
      } catch (_) {
      } finally {
        _processingImage = false;
      }
    });

    emit(state.copyWith(isStreaming: true));
  }

  Future<void> stopScanning() async {
    await controller.stopImageStream();
    emit(state.copyWith(isStreaming: false));
  }
}
