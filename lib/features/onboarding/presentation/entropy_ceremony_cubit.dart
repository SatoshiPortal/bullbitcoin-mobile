import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/domain/usecases/mix_entropy_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum PointerSampleKind { down, move }

typedef ElapsedMicroseconds = int Function();

class EntropyCeremonyState {
  const EntropyCeremonyState({
    this.eventCount = 0,
    this.elapsedDurationMicros = 0,
    this.horizontalCoverage = 0,
    this.verticalCoverage = 0,
  });

  /// Qualified pointer samples collected so far. This is ceremony pacing only,
  /// not an estimate of entropy bits.
  final int eventCount;

  /// Monotonic time between the first and latest accepted samples.
  final int elapsedDurationMicros;
  final double horizontalCoverage;
  final double verticalCoverage;

  static const targetEventCount = MixEntropyUsecase.requiredSampleCount;
  static const minimumElapsedDuration = Duration(seconds: 10);
  static const minimumAxisCoverage = 0.5;

  double get progress {
    final sampleProgress = eventCount / targetEventCount;
    final durationProgress =
        elapsedDurationMicros / minimumElapsedDuration.inMicroseconds;
    final coverageProgress =
        math.min(horizontalCoverage, verticalCoverage) / minimumAxisCoverage;
    return math
        .min(sampleProgress, math.min(durationProgress, coverageProgress))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  bool get isComplete =>
      eventCount >= targetEventCount &&
      elapsedDurationMicros >= minimumElapsedDuration.inMicroseconds &&
      horizontalCoverage >= minimumAxisCoverage &&
      verticalCoverage >= minimumAxisCoverage;

  int get decile => isComplete ? 10 : (progress * 10).floor();

  bool get hasStarted => eventCount > 0;
}

/// Serializes pointer samples and feeds them into the current pool ceremony.
class EntropyCeremonyCubit extends Cubit<EntropyCeremonyState> {
  EntropyCeremonyCubit({
    required this._mixEntropyUsecase,
    this.elapsedMicroseconds,
  }) : super(const EntropyCeremonyState());

  static const serializedSampleBytes = 128;

  final MixEntropyUsecase _mixEntropyUsecase;
  final ElapsedMicroseconds? elapsedMicroseconds;
  final Stopwatch _stopwatch = Stopwatch();
  bool _started = false;
  (double, double)? _lastAcceptedPosition;
  int? _firstAcceptedMicros;
  double? _minimumNormalizedX;
  double? _maximumNormalizedX;
  double? _minimumNormalizedY;
  double? _maximumNormalizedY;

  void start() {
    if (_started) return;
    _started = true;
    _stopwatch.start();
    _mixEntropyUsecase.begin();
  }

  /// Returns whether this sample was mixed and counted toward completion.
  bool addPointerSample({
    required PointerSampleKind kind,
    required int pointer,
    required int deviceKind,
    required double x,
    required double y,
    required double canvasWidth,
    required double canvasHeight,
    required double dx,
    required double dy,
    required int timestampMicros,
    required double pressure,
    required double radiusMajor,
    required double radiusMinor,
    required double size,
    required double orientation,
    required double tilt,
    required bool synthesized,
  }) {
    if (!_started) {
      throw StateError('Entropy ceremony has not started');
    }
    if (state.isComplete || synthesized) return false;

    final position = (x, y);
    if (!x.isFinite ||
        !y.isFinite ||
        !dx.isFinite ||
        !dy.isFinite ||
        !canvasWidth.isFinite ||
        !canvasHeight.isFinite ||
        canvasWidth <= 0 ||
        canvasHeight <= 0 ||
        position == _lastAcceptedPosition) {
      return false;
    }

    final elapsedTicks = _stopwatch.elapsedTicks;
    final elapsedMicros =
        elapsedMicroseconds?.call() ?? _stopwatch.elapsedMicroseconds;
    final sequence = state.eventCount;
    final bytes = Uint8List(serializedSampleBytes);
    final view = ByteData.view(bytes.buffer);
    view.setUint64(0, kind.index);
    view.setUint64(8, pointer);
    view.setUint64(16, sequence);
    view.setUint64(24, deviceKind);
    view.setFloat64(32, x);
    view.setFloat64(40, y);
    view.setFloat64(48, dx);
    view.setFloat64(56, dy);
    view.setUint64(64, timestampMicros);
    view.setUint64(72, elapsedTicks);
    view.setFloat64(80, pressure);
    view.setFloat64(88, radiusMajor);
    view.setFloat64(96, radiusMinor);
    view.setFloat64(104, size);
    view.setFloat64(112, orientation);
    view.setFloat64(120, tilt);

    try {
      _mixEntropyUsecase.execute(bytes);
    } finally {
      _zero(bytes);
    }

    _lastAcceptedPosition = position;
    final nextCount = state.eventCount + 1;
    final firstAcceptedMicros = _firstAcceptedMicros ?? elapsedMicros;
    _firstAcceptedMicros = firstAcceptedMicros;

    final normalizedX = (x / canvasWidth).clamp(0.0, 1.0).toDouble();
    final normalizedY = (y / canvasHeight).clamp(0.0, 1.0).toDouble();
    _minimumNormalizedX = math.min(
      _minimumNormalizedX ?? normalizedX,
      normalizedX,
    );
    _maximumNormalizedX = math.max(
      _maximumNormalizedX ?? normalizedX,
      normalizedX,
    );
    _minimumNormalizedY = math.min(
      _minimumNormalizedY ?? normalizedY,
      normalizedY,
    );
    _maximumNormalizedY = math.max(
      _maximumNormalizedY ?? normalizedY,
      normalizedY,
    );

    final nextState = EntropyCeremonyState(
      eventCount: nextCount,
      elapsedDurationMicros: math.max(0, elapsedMicros - firstAcceptedMicros),
      horizontalCoverage: _maximumNormalizedX! - _minimumNormalizedX!,
      verticalCoverage: _maximumNormalizedY! - _minimumNormalizedY!,
    );
    if (nextState.isComplete) {
      _mixEntropyUsecase.complete();
    }
    emit(nextState);
    return true;
  }

  static void _zero(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }
}
