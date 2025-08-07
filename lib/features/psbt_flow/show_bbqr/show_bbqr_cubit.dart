import 'dart:async';

import 'package:bb_mobile/features/psbt_flow/show_bbqr/show_bbqr_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ShowBbqrCubit extends Cubit<ShowBbqrState> {
  final List<String> parts;
  final Duration cycleInterval;
  Timer? _timer;

  ShowBbqrCubit({
    required this.parts,
    this.cycleInterval = const Duration(seconds: 2),
  }) : super(ShowBbqrState(parts: parts)) {
    _startCycling();
  }

  void _startCycling() {
    _timer?.cancel();
    _timer = Timer.periodic(cycleInterval, (_) {
      final nextIndex = (state.currentIndex + 1) % parts.length;
      emit(state.copyWith(currentIndex: nextIndex));
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
