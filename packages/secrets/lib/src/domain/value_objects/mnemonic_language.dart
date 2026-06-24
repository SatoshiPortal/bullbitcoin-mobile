import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:meta/meta.dart';

/// Supported BIP39 mnemonic languages. Mirrors `bip39_mnemonic`'s `Language`,
/// but kept as the package's own enum so the public API never leaks the
/// third-party type — callers use [MnemonicLanguage]; only the package's
/// adapters map across the single [asBip39] point. `importMnemonic`/
/// `fingerprintOf` default to [english].
enum MnemonicLanguage {
  english,
  french,
  spanish,
  italian,
  portuguese,
  czech,
  korean,
  simplifiedChinese,
  traditionalChinese,
  japanese;

  /// The matching `bip39_mnemonic` language. `@internal` so the public API
  /// never leaks the third-party enum — this is the single conversion point.
  @internal
  bip39.Language get asBip39 => switch (this) {
        MnemonicLanguage.english => bip39.Language.english,
        MnemonicLanguage.french => bip39.Language.french,
        MnemonicLanguage.spanish => bip39.Language.spanish,
        MnemonicLanguage.italian => bip39.Language.italian,
        MnemonicLanguage.portuguese => bip39.Language.portuguese,
        MnemonicLanguage.czech => bip39.Language.czech,
        MnemonicLanguage.korean => bip39.Language.korean,
        MnemonicLanguage.simplifiedChinese => bip39.Language.simplifiedChinese,
        MnemonicLanguage.traditionalChinese =>
          bip39.Language.traditionalChinese,
        MnemonicLanguage.japanese => bip39.Language.japanese,
      };

  /// Tolerant lookup by enum name for the storage-decode path. Returns null on
  /// an unrecognized name (the caller defaults to [english]) rather than
  /// throwing — decoding stays forward-compatible.
  static MnemonicLanguage? fromName(String name) {
    for (final l in MnemonicLanguage.values) {
      if (l.name == name) return l;
    }
    return null;
  }
}
