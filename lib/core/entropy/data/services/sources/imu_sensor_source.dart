import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/domain/entropy_source.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// MEMS inertial sensor noise: accelerometer, gyroscope and magnetometer
/// sampled at the fastest rate the hardware allows. The low-order bits are
/// thermal/electronic noise even on a stationary device; in-hand during the
/// entropy ceremony the readings additionally carry physiological hand
/// tremor. Full-precision doubles are mixed unfiltered — rounding or
/// smoothing would throw away exactly the bits we want.
class ImuSensorSource implements EntropySource {
  const ImuSensorSource({this.window = const Duration(milliseconds: 1500)});

  final Duration window;

  @override
  String get name => EntropySourceName.imu;

  @override
  bool get mandatory => false;

  @override
  Future<Uint8List> collect() async {
    final builder = BytesBuilder(copy: false);
    final stopwatch = Stopwatch()..start();

    void addSample(double x, double y, double z) {
      final bytes = Uint8List(32);
      final view = ByteData.view(bytes.buffer);
      view.setFloat64(0, x);
      view.setFloat64(8, y);
      view.setFloat64(16, z);
      view.setUint64(24, stopwatch.elapsedTicks);
      builder.add(bytes);
    }

    final subscriptions = <StreamSubscription<dynamic>>[
      accelerometerEventStream(
        samplingPeriod: SensorInterval.fastestInterval,
      ).listen((e) => addSample(e.x, e.y, e.z), onError: (_) {}),
      gyroscopeEventStream(
        samplingPeriod: SensorInterval.fastestInterval,
      ).listen((e) => addSample(e.x, e.y, e.z), onError: (_) {}),
      magnetometerEventStream(
        samplingPeriod: SensorInterval.fastestInterval,
      ).listen((e) => addSample(e.x, e.y, e.z), onError: (_) {}),
    ];

    try {
      await Future<void>.delayed(window);
    } finally {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    }

    return builder.takeBytes();
  }
}
