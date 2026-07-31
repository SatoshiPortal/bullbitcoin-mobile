import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/data/services/entropy_collector.dart';
import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:bb_mobile/core/entropy/domain/entropy_source.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

/// Generates a fresh 24-word (256-bit) mnemonic from the entropy pool.
///
/// The seed is `SHA512(bdk RNG ‖ OS RNG ‖ jitter ‖ stats ‖ ceremony ‖ state)`
/// — bdk's own RNG draw is mixed as a mandatory source rather than used
/// directly, so the result is at least as strong as what bdk alone would
/// have produced, no matter what the additional sources contribute.
///
/// The two mandatory sources give implementation-path diversity, not
/// independent entropy roots: the bdk draw comes from Rust's userspace
/// `thread_rng` and the Dart source from `Random.secure()`, both ultimately
/// reseeded from the same OS entropy root. A bug in either *binding* alone
/// cannot determine the seed; a fully compromised kernel RNG affects both,
/// which is what the additional environmental sources mitigate.
class MnemonicGenerator {
  MnemonicGenerator({
    required EntropyPool entropyPool,
    required EntropyCollector entropyCollector,
  }) : _entropyPool = entropyPool,
       _entropyCollector = entropyCollector;

  final EntropyPool _entropyPool;
  final EntropyCollector _entropyCollector;

  /// Serializes generations: the pool's collect → mix → extract sequence is
  /// one transaction and must never interleave with another generation.
  Future<void> _queue = Future.value();

  static const _wordCount = 24;
  static const _entropyBytes = 32;

  Future<List<String>> generate() {
    final result = _queue.then((_) => _generate());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<String>> _generate() async {
    try {
      // Baseline collection runs on every generation so the mandatory OS
      // RNG floor never depends on UI flows having fed the pool first.
      // Ceremony/sensor entropy mixed earlier is already in the state.
      await _entropyCollector.collectAll();

      // bdk's RNG draw exists only to be mixed: never used as the seed,
      // never logged, never shown.
      final bdkDraw = bdk.Mnemonic(wordCount: bdk.WordCount.words24);
      Uint8List? drawBytes;
      try {
        drawBytes = Uint8List.fromList(utf8.encode(bdkDraw.toString()));
        _entropyPool.mixMandatory(EntropySourceName.bdkRng, drawBytes);
      } finally {
        _zero(drawBytes);
        bdkDraw.dispose();
      }

      Uint8List? entropy;
      bdk.Mnemonic? mnemonic;
      try {
        entropy = _entropyPool.extract(_entropyBytes);
        mnemonic = bdk.Mnemonic.fromEntropy(entropy: entropy);
        final mnemonicWords = mnemonic.toString().split(' ');
        if (mnemonicWords.length != _wordCount) {
          throw FailedToGenerateMnemonicException(
            'Expected $_wordCount words, got ${mnemonicWords.length}',
          );
        }
        return mnemonicWords;
      } finally {
        // Best-effort hygiene on every exit path: the FFI call copied the
        // entropy, and the words are the caller's responsibility from here.
        // GC duplicates remain possible, as everywhere in the seed path.
        _zero(entropy);
        mnemonic?.dispose();
      }
    } on FailedToGenerateMnemonicException {
      rethrow;
    } catch (e) {
      throw FailedToGenerateMnemonicException(e.toString());
    }
  }

  static void _zero(Uint8List? bytes) {
    if (bytes == null) return;
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }
}

class FailedToGenerateMnemonicException extends BullException {
  FailedToGenerateMnemonicException(super.message);
}
