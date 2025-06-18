import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/scan/data/scan_service.dart';
import 'package:bb_mobile/features/scan/presentation/scan_state.dart';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ScanCubit extends Cubit<ScanState> {
  final CameraController controller;

  ScanCubit({required this.controller}) : super(ScanState.initial());

  void dispose() {
    controller.stopImageStream();
    controller.dispose();
  }

  Future<void> openCamera() async {
    // Added delay for iOS to ensure camera is fully initialized
    if (Platform.isIOS) await Future.delayed(const Duration(milliseconds: 100));

    await controller.startImageStream((CameraImage image) async {
      if (state.processingImage) return;
      emit(state.copyWith(processingImage: true));

      try {
        final imageBytes = image.planes[0].bytes;
        final qr = ScanService.decode(imageBytes, image.width, image.height);

        if (qr.isNotEmpty && qr != state.data.$1) {
          try {
            final pr = await PaymentRequest.parse(qr);
            emit(state.copyWith(data: (qr, pr)));
            log.info('SCAN PaymentRequest: ${pr.runtimeType}');
          } catch (e) {
            log.warning('$PaymentRequest not found $e');
          }
        }

        emit(state.copyWith(data: (qr, null)));
      } catch (e) {
        log.severe('Error decoding QR: $e');
      }
      emit(state.copyWith(processingImage: false));
    });
  }
}
