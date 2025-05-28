import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/scan/bbqr_service.dart' show BbqrService;
import 'package:bb_mobile/features/scan/presentation/scan_state.dart';
import 'package:bb_mobile/features/scan/scan_service.dart';

import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:camera/camera.dart';
import 'package:dart_bbqr/bbqr.dart' as bbqr show Joined;
import 'package:flutter/foundation.dart';
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

        final qr = ScanService.decode(imageBytes, image.width, image.height);

        if (state.isCollectingBbqr) {
          final psbt = await tryToCollectBbqrPsbt(qr);
          if (psbt != null) {
            final pr = await PaymentRequest.parse(psbt);
            if (pr is PsbtPaymentRequest) emit(state.copyWith(data: (qr, pr)));
          }
        } else {
          if (qr.isNotEmpty && qr != state.data.$1) {
            try {
              final pr = await PaymentRequest.parse(qr);
              emit(state.copyWith(data: (qr, pr)));
            } catch (e) {
              debugPrint('$PaymentRequest not found $e');
            }
          }

          emit(state.copyWith(data: (qr, null)));
        }
      } catch (_) {}
      _processingImage = false;
    });
  }

  Future<String?> tryToCollectBbqrPsbt(String payload) async {
    if (!BbqrService.isValid(payload)) return null;

    final options = BbqrService.decodeOptions(payload);
    final updatedBbqr = Map<int, String>.from(state.bbqr);
    updatedBbqr[options.share] = payload;
    emit(state.copyWith(bbqr: updatedBbqr, bbqrOptions: options));

    if (options.total < updatedBbqr.length) {
      // reset another state.bbqr
      // and expect the next scan to be a new BBQR
      emit(state.copyWith(bbqr: {}));
      return null;
    }

    if (options.total == updatedBbqr.length) {
      final bbqrParts = updatedBbqr.values.toList();
      final bbqrJoiner = await bbqr.Joined.tryFromParts(parts: bbqrParts);
      final psbt = await PartiallySignedTransaction.fromString(
        base64.encode(bbqrJoiner.data), // Psbt bytes
      );
      return psbt.toString();
    }

    return null;
  }

  void switchBbqr() => emit(
    state.copyWith(isCollectingBbqr: !state.isCollectingBbqr),
  ); // reset state
}
