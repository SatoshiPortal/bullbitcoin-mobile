import 'dart:async';

import 'package:bb_mobile/core_deprecated/bbqr/bbqr.dart';
import 'package:bb_mobile/core_deprecated/entities/signer_device_entity.dart';
import 'package:bb_mobile/core_deprecated/urqr/urqr.dart';
import 'package:bb_mobile/features/psbt_flow/show_animated_qr/show_animated_qr_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ShowAnimatedQrCubit extends Cubit<ShowAnimatedQrState> {
  final String psbt;
  final QrType qrType;
  Timer? _timer;

  ShowAnimatedQrCubit({
    required this.psbt,
    required this.qrType,
  }) : super(const ShowAnimatedQrState()) {
    _generateQrParts();
  }

  Future<void> _generateQrParts() async {
    try {
      emit(state.copyWith(isLoading: true, error: null));

      final parts = switch (qrType) {
        QrType.bbqr => await Bbqr.splitPsbt(psbt),
        QrType.urqr => UrQrGenerator.generatePsbtUr(psbt, fragmentLength: state.fragmentLength),
        QrType.none => <String>[],
      };

      emit(state.copyWith(
        isLoading: false,
        parts: parts,
        currentIndex: 0,
        error: null,
      ));

      if (parts.isNotEmpty) {
        _startCycling();
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
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
