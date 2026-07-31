import 'dart:isolate';
import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/domain/entropy_source.dart';

/// Clock-domain jitter, the same physical phenomenon the Linux kernel's
/// jitterentropy driver harvests: a busy loop counts how much work fits
/// between successive microsecond timer ticks. The variation comes from
/// independent oscillators drifting against each other plus cache misses,
/// interrupts, DVFS and scheduler preemption. Runs on a worker isolate so
/// the ~25ms of spinning never janks the UI.
class CpuJitterSource implements EntropySource {
  const CpuJitterSource();

  static const _samples = 512;
  static const _maxMillis = 25;

  // Hard bound independent of the clock: if the monotonic timer ever froze,
  // the time- and sample-based bounds below would never trigger and the
  // worker isolate would spin forever (the collector timeout abandons the
  // future but cannot kill the isolate).
  static const _maxSpins = 50000000;

  @override
  String get name => EntropySourceName.cpuJitter;

  @override
  bool get mandatory => false;

  @override
  Future<Uint8List> collect() => Isolate.run(_sampleJitter);

  static Uint8List _sampleJitter() {
    final stopwatch = Stopwatch()..start();
    final readings = <int>[];
    var last = stopwatch.elapsedMicroseconds;
    var spins = 0;
    var totalSpins = 0;
    while (readings.length < _samples * 2 &&
        stopwatch.elapsedMilliseconds < _maxMillis &&
        totalSpins < _maxSpins) {
      final now = stopwatch.elapsedMicroseconds;
      if (now != last) {
        readings
          ..add(spins)
          ..add(now - last);
        spins = 0;
        last = now;
      }
      spins++;
      totalSpins++;
    }
    readings
      ..add(stopwatch.elapsedTicks)
      ..add(stopwatch.frequency);

    final bytes = Uint8List(readings.length * 8);
    final view = ByteData.view(bytes.buffer);
    for (var i = 0; i < readings.length; i++) {
      view.setUint64(i * 8, readings[i]);
    }
    return bytes;
  }
}
