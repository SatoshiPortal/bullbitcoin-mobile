import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';

/// Folds caller-supplied entropy (e.g. touch events from the onboarding
/// entropy ceremony) into the global pool. Strictly additive: whatever the
/// caller sends can only add unpredictability, never remove it.
class MixEntropyUsecase {
  const MixEntropyUsecase({required EntropyPool entropyPool})
    : _entropyPool = entropyPool;

  final EntropyPool _entropyPool;

  void execute({required String source, required Uint8List data}) {
    _entropyPool.mix(source, data);
  }
}
