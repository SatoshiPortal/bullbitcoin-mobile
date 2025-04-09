import 'package:bb_mobile/features/scan/presentation/scan_state.dart';
import 'package:bb_mobile/features/scan/scan_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ScanCubit extends Cubit<ScanState> {
  final CameraController controller;

  ScanCubit({required this.controller}) : super(ScanState.initial());

  Future<void> startScanning() async {
    await controller.startImageStream((CameraImage image) {
      try {
        final yPlaneBytes = image.planes[0].bytes;
        final qrText = ScanService.decode(
          yPlaneBytes,
          image.width,
          image.height,
        );

        if (qrText.isNotEmpty) {
          emit(state.copyWith(data: qrText));
        }
      } catch (_) {}
    });

    emit(state.copyWith(isStreaming: true));
  }

  Future<void> stopScanning() async {
    await controller.stopImageStream();
    emit(state.copyWith(isStreaming: false));
  }
}
