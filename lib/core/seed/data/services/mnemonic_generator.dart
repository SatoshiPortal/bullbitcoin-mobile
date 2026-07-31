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
/// have produced, no matter what the additional sources contribute. The two
/// mandatory sources reach the kernel CSPRNG through independent bindings
/// (Rust getrandom for bdk, Dart Random.secure for the OS source), so a bug
/// in either one alone can no longer determine the seed.
class MnemonicGenerator {
  const MnemonicGenerator({
    required EntropyPool entropyPool,
    required EntropyCollector entropyCollector,
  }) : _entropyPool = entropyPool,
       _entropyCollector = entropyCollector;

  final EntropyPool _entropyPool;
  final EntropyCollector _entropyCollector;

  static const _wordCount = 24;
  static const _entropyBytes = 32;

  Future<List<String>> generate() async {
    try {
      // Baseline collection runs on every generation so the mandatory OS
      // RNG floor never depends on UI flows having fed the pool first.
      // Ceremony/sensor entropy mixed earlier is already in the state.
      await _entropyCollector.collectAll();

      // bdk's RNG draw exists only to be mixed: never used as the seed,
      // never logged, never shown.
      final bdkDraw = bdk.Mnemonic(wordCount: bdk.WordCount.words24);
      _entropyPool.mix(
        EntropySourceName.bdkRng,
        Uint8List.fromList(utf8.encode(bdkDraw.toString())),
      );

      final entropy = _entropyPool.extract(_entropyBytes);
      final mnemonic = bdk.Mnemonic.fromEntropy(entropy: entropy);
      // Best-effort hygiene: the FFI call copied the bytes, so drop the
      // Dart-side copy (GC duplicates remain possible, as everywhere in
      // the seed path).
      for (var i = 0; i < entropy.length; i++) {
        entropy[i] = 0;
      }

      final mnemonicWords = mnemonic.toString().split(' ');
      if (mnemonicWords.length != _wordCount) {
        throw FailedToGenerateMnemonicException(
          'Expected $_wordCount words, got ${mnemonicWords.length}',
        );
      }
      return mnemonicWords;
    } on FailedToGenerateMnemonicException {
      rethrow;
    } catch (e) {
      throw FailedToGenerateMnemonicException(e.toString());
    }
  }
}

class FailedToGenerateMnemonicException extends BullException {
  FailedToGenerateMnemonicException(super.message);
}
