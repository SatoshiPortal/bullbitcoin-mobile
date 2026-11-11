import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;

/// The wordlist a stored or vaulted `language` value names: bip39's own [Language.label], which is what the package writes. Callers default only for an absent key; any other value, null included, is refused.
Language languageFromLabel(Object? value) => Language.values.firstWhere(
  (language) => language.label == value,
  orElse: () => throw const FormatException('unknown mnemonic language'),
);
