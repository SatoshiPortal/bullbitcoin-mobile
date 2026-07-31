import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/domain/usecases/mix_entropy_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum PointerSampleKind { down, move }

class EntropyCeremonyState {
  const EntropyCeremonyState({this.eventCount = 0});

  /// Pointer samples collected so far. This is ceremony pacing only, not an
  /// estimate of entropy bits.
  final int eventCount;

  static const targetEventCount = MixEntropyUsecase.requiredSampleCount;

  double get progress =>
      (eventCount / targetEventCount).clamp(0.0, 1.0).toDouble();

  bool get isComplete => eventCount >= targetEventCount;

  int get decile => isComplete ? 10 : (progress * 10).floor();

  bool get hasStarted => eventCount > 0;
}

/// Serializes pointer samples and feeds them into the current pool ceremony.
class EntropyCeremonyCubit extends Cubit<EntropyCeremonyState> {
  EntropyCeremonyCubit({required MixEntropyUsecase mixEntropyUsecase})
    : _mixEntropyUsecase = mixEntropyUsecase,
      super(const EntropyCeremonyState());

  final MixEntropyUsecase _mixEntropyUsecase;
  final Stopwatch _stopwatch = Stopwatch();
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _stopwatch.start();
    _mixEntropyUsecase.begin();
  }

  void addPointerSample({
    required PointerSampleKind kind,
    required int pointer,
    required double x,
    required double y,
    required double dx,
    required double dy,
    required int timestampMicros,
    required double pressure,
    required double radiusMajor,
  }) {
    if (!_started) {
      throw StateError('Entropy ceremony has not started');
    }
    if (state.isComplete) return;

    final bytes = Uint8List(80);
    final view = ByteData.view(bytes.buffer);
    view.setUint64(0, kind.index);
    view.setUint64(8, pointer);
    view.setFloat64(16, x);
    view.setFloat64(24, y);
    view.setFloat64(32, dx);
    view.setFloat64(40, dy);
    view.setUint64(48, timestampMicros);
    view.setUint64(56, _stopwatch.elapsedTicks);
    view.setFloat64(64, pressure);
    view.setFloat64(72, radiusMajor);

    try {
      _mixEntropyUsecase.execute(bytes);
    } finally {
      _zero(bytes);
    }

    final nextCount = state.eventCount + 1;
    if (nextCount == EntropyCeremonyState.targetEventCount) {
      _mixEntropyUsecase.complete();
    }
    emit(EntropyCeremonyState(eventCount: nextCount));
  }

  static void _zero(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }
}
