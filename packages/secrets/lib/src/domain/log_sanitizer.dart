import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

/// The BIP39 English wordlist (2048 words), built once. Used to detect real
/// mnemonic phrases precisely instead of redacting any run of short words.
final Set<String> _bip39English =
    bip39.Language.english.list.map((w) => w.toLowerCase()).toSet();

final RegExp _xprv =
    RegExp(r'\b(?:xprv|tprv|yprv|zprv|uprv|vprv)[1-9A-HJ-NP-Za-km-z]{50,}');
final RegExp _hex = RegExp(r'\b[0-9a-fA-F]{32,}\b');
final RegExp _word = RegExp(r'[A-Za-z]+');
// Tokens that can sit BETWEEN mnemonic words and still mean "same phrase":
// whitespace, commas, AND the quotes/brackets/punctuation a phrase picks up
// when echoed inside JSON (`["abandon","ability",...]`), pipes, slashes, etc.
// Requiring the words themselves to be BIP39 keeps prose from over-matching.
final RegExp _separators = RegExp(r'''^[\s,"'\[\]{}()|/:;.\-]+$''');

/// Redacts secret material from a string before it is attached to a
/// `Failure.logMessage` and sent to logs/Sentry (audit A3).
///
/// A raw crypto error can echo its secret input ("invalid xprv: tprv8...",
/// "bad mnemonic: zoo zoo zoo ..."). This is the single chokepoint every
/// boundary in `secrets` runs untrusted error text through before logging.
///
/// Redacts:
///  - extended private keys (`xprv`/`tprv`/… + base58),
///  - long hex blobs (>= 32 hex chars — 16+ byte keys/seeds; 8-hex
///    fingerprints are public and intentionally preserved),
///  - runs of >= 12 ADJACENT BIP39 words (a mnemonic phrase). Matching against
///    the real wordlist (not "any short word") means it redacts a capitalized /
///    comma-separated / embedded phrase but leaves ordinary prose readable.
String sanitizeLog(String? input) {
  if (input == null || input.isEmpty) return '';
  var out = input;
  out = out.replaceAll(_xprv, '[REDACTED_XPRV]');
  out = out.replaceAll(_hex, '[REDACTED_HEX]');
  out = _redactMnemonics(out);
  return out;
}

String _redactMnemonics(String input) {
  final words = _word.allMatches(input).toList();
  if (words.length < 12) return input;
  final isWord = [
    for (final m in words) _bip39English.contains(m.group(0)!.toLowerCase()),
  ];

  bool adjacent(int a, int b) =>
      _separators.hasMatch(input.substring(words[a].end, words[b].start));

  final ranges = <List<int>>[]; // [start, end] char offsets to redact
  var i = 0;
  while (i < words.length) {
    if (!isWord[i]) {
      i++;
      continue;
    }
    var j = i + 1;
    while (j < words.length && isWord[j] && adjacent(j - 1, j)) {
      j++;
    }
    if (j - i >= 12) ranges.add([words[i].start, words[j - 1].end]);
    i = j;
  }
  if (ranges.isEmpty) return input;

  final buf = StringBuffer();
  var last = 0;
  for (final r in ranges) {
    buf.write(input.substring(last, r[0]));
    buf.write('[REDACTED_MNEMONIC]');
    last = r[1];
  }
  buf.write(input.substring(last));
  return buf.toString();
}
