import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:bb_mobile/core/entropy/data/services/sources/os_rng_source.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

/// Generates a 12-word BIP39 mnemonic from explicitly combined entropy.
///
/// Every generation requires both a completed touch ceremony and a fresh
/// platform CSPRNG draw. BDK performs deterministic BIP39 encoding only; its
/// internal random mnemonic constructor is never used here.
class MnemonicGenerator {
  MnemonicGenerator({required this._entropyPool, required this._osRngSource});

  final EntropyPool _entropyPool;
  final OsRngSource _osRngSource;

  /// Serializes the OS draw, pool extraction, and mnemonic conversion.
  Future<void> _queue = Future.value();

  static const _wordCount = 12;
  static const _entropyBytes = 16;

  Future<List<String>> generate() {
    final result = _queue.then((_) => _generate());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<String>> _generate() async {
    Uint8List? osEntropy;
    Uint8List? mnemonicEntropy;
    bdk.Mnemonic? mnemonic;
    try {
      osEntropy = await _osRngSource.collect();
      mnemonicEntropy = _entropyPool.extractWithOsEntropy(
        osEntropy,
        _entropyBytes,
      );
      mnemonic = bdk.Mnemonic.fromEntropy(entropy: mnemonicEntropy);

      final words = mnemonic.toString().split(' ');
      if (words.length != _wordCount) {
        throw FailedToGenerateMnemonicException(
          'Expected $_wordCount words, got ${words.length}',
        );
      }
      return words;
    } on FailedToGenerateMnemonicException {
      rethrow;
    } catch (e) {
      throw FailedToGenerateMnemonicException(e.toString());
    } finally {
      _zero(osEntropy);
      _zero(mnemonicEntropy);
      mnemonic?.dispose();
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
