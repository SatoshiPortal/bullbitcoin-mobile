import 'package:bip39_mnemonic/bip39_mnemonic.dart'
    show Language, Mnemonic, MnemonicException;
import 'package:unorm_dart/unorm_dart.dart' show nfkd;

/// Every BIP39 language, as sets of NFKD words: the lists the wallet itself
/// validates against, never a copy.
final _wordSets = [
  for (final language in Language.values)
    {for (final word in language.list) nfkd(word)},
];

/// Base58 alphabet, without `0`, `O`, `I` and `l`.
const _base58 = '[1-9A-HJ-NP-Za-km-z]';

/// An extended private key: `xprv`, `yprv`, `zprv`, `tprv`, `uprv`, `vprv`.
final _extendedPrivateKey = RegExp('\\b[xyztuvXYZTUV]prv$_base58{90,}');

/// A WIF private key, compressed or not, mainnet or testnet.
final _wif = RegExp('\\b[5KLc9]$_base58{50,51}\\b');

/// The shortest BIP39 phrase.
const _shortestPhrase = 12;

/// Whether free text carries what must never leave the phone: a run of at
/// least twelve consecutive words that all belong to one BIP39 word list (any of
/// the ten languages), an extended private key or a WIF key.
///
/// Text is segmented by Unicode, not by ASCII: a token is a run of letters,
/// combining marks and digits, so the ideographic space of Japanese phrases,
/// accents and decomposed accents all separate and join words correctly. Each
/// token is lowercased and put in NFKD, the form the lists are in. Pure and
/// conservative on purpose: a note that merely uses a few common words is fine,
/// a phrase-shaped run is not. It reads the text only, never a seed.
bool looksLikeSecretMaterial(String text) {
  if (_extendedPrivateKey.hasMatch(text) || _wif.hasMatch(text)) return true;
  final tokens = [
    for (final raw in text.split(_notWordCharacter))
      if (raw.isNotEmpty) nfkd(raw.toLowerCase()),
  ];
  // Chinese lists hold one character per word, and phrases are often written
  // with no separator. Ordinary text is made of the same common characters, so
  // only a whole segment with a valid checksum counts.
  for (final language in _characterLanguages) {
    for (final token in tokens) {
      final characters = token.runes.map(String.fromCharCode).toList();
      final length = characters.length;
      if (length >= _shortestPhrase &&
          length <= 24 &&
          length % 3 == 0 &&
          characters.every(language.list.contains)) {
        try {
          Mnemonic.fromWords(words: characters, language: language);
          return true;
        } on MnemonicException {
          // This segment is not a valid phrase in this language.
        }
      }
    }
  }
  for (final words in _wordSets) {
    var run = 0;
    for (final token in tokens) {
      if (words.contains(token)) {
        if (++run >= _shortestPhrase) return true;
      } else {
        run = 0;
      }
    }
  }
  return false;
}

/// The lists whose words are all one character (the two Chinese ones).
final _characterLanguages = [
  Language.simplifiedChinese,
  Language.traditionalChinese,
];

/// Anything that is not a letter, a combining mark or a digit.
final _notWordCharacter = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);
