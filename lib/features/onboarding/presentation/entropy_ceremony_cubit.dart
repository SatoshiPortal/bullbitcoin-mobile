import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/domain/entropy_source.dart';
import 'package:bb_mobile/core/entropy/domain/usecases/collect_sensor_entropy_usecase.dart';
import 'package:bb_mobile/core/entropy/domain/usecases/mix_entropy_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EntropyCeremonyState {
  const EntropyCeremonyState({this.eventCount = 0});

  /// Pointer move events collected so far. Purely a pacing counter for the
  /// progress bar — never a measured entropy claim. The security floor is
  /// the pool's mandatory OS+bdk RNG gate, not this number.
  final int eventCount;

  /// ~2 bits of timing jitter credited per move event; bar fills at 256
  /// credited bits worth of margin (VeraCrypt-style pacing).
  static const targetEventCount = 300;

  double get progress =>
      (eventCount / targetEventCount).clamp(0.0, 1.0).toDouble();

  bool get isComplete => eventCount >= targetEventCount;

  /// 10%-decile the bar has reached (0..10), driving the milestone messages.
  int get decile => isComplete ? 10 : (progress * 10).floor();

  bool get hasStarted => eventCount > 0;
}

/// Feeds the onboarding entropy ceremony into the pool: every raw pointer
/// sample is mixed as it arrives, and IMU sensor windows are collected
/// continuously while the screen is open. Everything here is additive on
/// top of the mandatory RNG floor.
class EntropyCeremonyCubit extends Cubit<EntropyCeremonyState> {
  EntropyCeremonyCubit({
    required MixEntropyUsecase mixEntropyUsecase,
    required CollectSensorEntropyUsecase collectSensorEntropyUsecase,
  }) : _mixEntropyUsecase = mixEntropyUsecase,
       _collectSensorEntropyUsecase = collectSensorEntropyUsecase,
       super(const EntropyCeremonyState());

  final MixEntropyUsecase _mixEntropyUsecase;
  final CollectSensorEntropyUsecase _collectSensorEntropyUsecase;
  final Stopwatch _stopwatch = Stopwatch()..start();
  bool _sensorLoopRunning = false;

  /// Starts the background IMU sampling loop for the lifetime of the screen.
  ///
  /// Each round is paced to at least the sensor window so a device where
  /// collection fails fast (no sensors, missing plugin) cannot turn this
  /// into a busy loop.
  Future<void> start() async {
    if (_sensorLoopRunning) return;
    _sensorLoopRunning = true;
    const minRoundDuration = Duration(milliseconds: 1500);
    while (!isClosed) {
      final round = Stopwatch()..start();
      await _collectSensorEntropyUsecase.execute();
      final remaining = minRoundDuration - round.elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    }
  }

  void addPointerSample({
    required double x,
    required double y,
    required double dx,
    required double dy,
    required int timestampMicros,
    required double pressure,
    required double radiusMajor,
  }) {
    final bytes = Uint8List(64);
    final view = ByteData.view(bytes.buffer);
    view.setFloat64(0, x);
    view.setFloat64(8, y);
    view.setFloat64(16, dx);
    view.setFloat64(24, dy);
    view.setUint64(32, timestampMicros);
    view.setUint64(40, _stopwatch.elapsedTicks);
    view.setFloat64(48, pressure);
    view.setFloat64(56, radiusMajor);
    _mixEntropyUsecase.execute(source: EntropySourceName.touch, data: bytes);

    if (!state.isComplete) {
      emit(EntropyCeremonyState(eventCount: state.eventCount + 1));
    }
  }
}
