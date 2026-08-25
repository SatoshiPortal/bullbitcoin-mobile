import 'dart:async';

import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/urqr/urqr.dart';
import 'package:bb_mobile/core/widgets/animated_psbt_qr/show_animated_qr_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ShowAnimatedQrCubit extends Cubit<ShowAnimatedQrState> {
  final String psbt;
  final QrType qrType;
  Timer? _timer;

  ShowAnimatedQrCubit({required this.psbt, required this.qrType})
    : super(const ShowAnimatedQrState()) {
    _generateQrParts();
  }

  Future<void> _generateQrParts() async {
    try {
      emit(state.copyWith(isLoading: true, isTooLarge: false, error: null));

      var fragmentLength = state.fragmentLength;
      List<String> parts;
      try {
        parts = await _parts(fragmentLength);
        if (isClosed) return;
      } on UrSequenceLimitExceeded {
        if (qrType != QrType.urqr || fragmentLength >= 200) rethrow;
        fragmentLength = 200;
        parts = await _parts(fragmentLength);
        if (isClosed) return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          parts: parts,
          currentIndex: 0,
          fragmentLength: fragmentLength,
          isTooLarge: false,
          error: null,
        ),
      );

      if (parts.isNotEmpty) {
        _startCycling();
      }
    } on UrSequenceLimitExceeded {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          parts: const [],
          isTooLarge: true,
          error: null,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<List<String>> _parts(int fragmentLength) async => switch (qrType) {
    QrType.bbqr => Bbqr.splitPsbt(psbt),
    QrType.urqr => UrQrGenerator.generatePsbtUr(
      psbt,
      fragmentLength: fragmentLength,
    ),
    QrType.none => <String>[],
  };

  void _startCycling() {
    _timer?.cancel();

    final interval = switch (qrType) {
      QrType.bbqr => const Duration(seconds: 2),
      QrType.urqr => const Duration(seconds: 1),
      QrType.none => const Duration(seconds: 2),
    };

    _timer = Timer.periodic(interval, (_) {
      if (isClosed) return;
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
