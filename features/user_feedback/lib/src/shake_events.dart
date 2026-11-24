import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:user_feedback/src/shake_detector.dart';

const _iosShakeChannel = EventChannel('com.bullbitcoin.user_feedback/shake');

/// One event per shake of the phone.
///
/// iOS: the system shake gesture, from the native plugin. It needs no sensor
/// stream and also fires from the Simulator's Device > Shake.
/// Android, which has no system shake gesture: the accelerometer, through
/// [ShakeDetector].
Stream<void> shakeEvents() {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return _iosShakeChannel.receiveBroadcastStream().map((_) {});
  }
  final detector = ShakeDetector();
  return userAccelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      )
      .where(
        (event) => detector.add(
          x: event.x,
          y: event.y,
          z: event.z,
          at: event.timestamp,
        ),
      )
      .map((_) {});
}
