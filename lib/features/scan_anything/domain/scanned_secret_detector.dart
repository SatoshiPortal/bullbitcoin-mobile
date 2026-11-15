import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:unorm_dart/unorm_dart.dart';

abstract final class ScannedSecretDetector {
  static const _mnemonicLengths = {12, 15, 18, 21, 24};
  static final _extendedPrivateKey = RegExp(
    r'(?<![A-Za-z0-9])(xprv|yprv|zprv|tprv|uprv|vprv)[1-9A-HJ-NP-Za-km-z]+',
  );
  static final _wif = RegExp(
    r'^(?:[5KL][1-9A-HJ-NP-Za-km-z]{50,51}|[9c][1-9A-HJ-NP-Za-km-z]{50,51})$',
  );

  static bool isRecoveryPhrase(String input) {
    final words = input
        .trim()
        .split(RegExp(r'\s+'))
        .map((word) => nfkd(word).toLowerCase())
        .where((word) => word.isNotEmpty)
        .toList();
    if (!_mnemonicLengths.contains(words.length)) return false;
    for (final language in bip39.Language.values) {
      if (!words.every(language.isValid)) continue;
      try {
        bip39.Mnemonic.fromWords(words: words, language: language);
        return true;
      } on bip39.MnemonicException {
        continue;
      }
    }
    return false;
  }

  static bool isPrivateKeyMaterial(String input) {
    final trimmed = input.trim();
    return _extendedPrivateKey.hasMatch(trimmed) || _wif.hasMatch(trimmed);
  }
}
