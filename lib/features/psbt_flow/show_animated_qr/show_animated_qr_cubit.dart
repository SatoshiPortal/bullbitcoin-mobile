import 'dart:async';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/psbt_flow/domain/generate_psbt_qr_parts_usecase.dart';
import 'package:bb_mobile/features/psbt_flow/show_animated_qr/show_animated_qr_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ShowAnimatedQrCubit extends Cubit<ShowAnimatedQrState> {
  final GeneratePsbtQrPartsUsecase _generatePsbtQrPartsUsecase;
  final String psbt;
  final QrType qrType;
  Timer? _timer;

  ShowAnimatedQrCubit({
    required this._generatePsbtQrPartsUsecase,
    required this.psbt,
    required this.qrType,
  }) : super(const ShowAnimatedQrState()) {
    _generateQrParts();
  }

  Future<void> _generateQrParts() async {
    emit(state.copyWith(isLoading: true, failure: null));

    final result = await _generatePsbtQrPartsUsecase.execute(
      psbt: psbt,
      qrType: qrType,
      fragmentLength: state.fragmentLength,
    );

    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            isLoading: false,
            parts: value,
            currentIndex: 0,
            failure: null,
          ),
        );
        if (value.isNotEmpty) _startCycling();
      case Err(:final failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  void _startCycling() {
    _timer?.cancel();

    final interval = switch (qrType) {
      QrType.bbqr => const Duration(seconds: 2),
      QrType.urqr => const Duration(seconds: 1),
      QrType.none => const Duration(seconds: 2),
    };

    _timer = Timer.periodic(interval, (_) {
      if (state.parts.isNotEmpty) {
        final nextIndex = (state.currentIndex + 1) % state.parts.length;
        emit(state.copyWith(currentIndex: nextIndex));
      }
    });
  }

  void updateFragmentLength(int fragmentLength) {
    emit(state.copyWith(fragmentLength: fragmentLength));
    _generateQrParts(); // Regenerate with new fragment length
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
