import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;

/// The stored spelling of a wordlist: its BIP39 wordlist file name in bitcoin/bips. Package-owned and frozen, so renaming an identifier of the bip39 package can never change bytes in the keystore.
String encodeLanguage(Language language) => switch (language) {
  Language.english => 'english',
  Language.japanese => 'japanese',
  Language.korean => 'korean',
  Language.spanish => 'spanish',
  Language.simplifiedChinese => 'chinese_simplified',
  Language.traditionalChinese => 'chinese_traditional',
  Language.french => 'french',
  Language.italian => 'italian',
  Language.czech => 'czech',
  Language.portuguese => 'portuguese',
};

/// Decodes an explicitly present language; callers default only for an absent key.
Language decodeLanguage(Object? value) {
  for (final language in Language.values) {
    if (encodeLanguage(language) == value) return language;
  }
  throw const FormatException('unknown mnemonic language');
}
