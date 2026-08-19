import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';

/// Owns the touch-ceremony lifecycle exposed to onboarding.
class MixEntropyUsecase {
  const MixEntropyUsecase({required this._entropyPool});

  static const requiredSampleCount = EntropyPool.requiredTouchSamples;

  final EntropyPool _entropyPool;

  void begin() => _entropyPool.beginTouchCeremony();

  void execute(Uint8List data) => _entropyPool.mixTouchSample(data);

  void complete() => _entropyPool.completeTouchCeremony();
}
