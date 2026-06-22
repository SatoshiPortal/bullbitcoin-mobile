import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

/// The BIP39 English wordlist (2048 words), built once. Used to detect real
/// mnemonic phrases precisely instead of redacting any run of short words.
final Set<String> _bip39English =
    bip39.Language.english.list.map((w) => w.toLowerCase()).toSet();

final RegExp _xprv = RegExp(
    r'\b(?:xprv|tprv|yprv|zprv|uprv|vprv)[1-9A-HJ-NP-Za-km-z]{50,}',
    caseSensitive: false);
// No leading `\b`: a hex run preceded by `0x` (where `0`/`x` are word chars)
// would NOT be at a word boundary, so an `0x<64hex>` blob would leak in clear.
// The trailing `\b` still keeps an 8-char fingerprint (len < 32) safe.
final RegExp _hex = RegExp(r'[0-9a-fA-F]{32,}\b');
// The at-rest sealed-secret format written by FssSecretStoreAdapter: the `s1:`
// version tag + base64 of the mnemonic JSON. A storage/decode error can echo a
// stored value verbatim (e.g. `FormatException: ... s1:eyJ...`); anchoring on
// the `s1:` tag redacts exactly that blob without touching ordinary base64
// (tx hex, descriptors) elsewhere in a log line.
final RegExp _sealedBlob = RegExp(r's1:[A-Za-z0-9+/]{16,}={0,2}');
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
  out = out.replaceAll(_sealedBlob, '[REDACTED_SEALED_BLOB]');
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

  // Redact a contiguous run of word-tokens that looks like a mnemonic,
  // TOLERATING mistyped / checksum-failing words inside it (a typo must not let
  // the other ~11 real words leak). The run is grown across <= 2 CONSECUTIVE
  // non-BIP39 tokens; 3+ in a row, or a non-separator gap, ends it — so
  // ordinary prose (sparse BIP39 words) is never redacted.
  //
  // The redaction trigger is COUNT-based, not a typo budget: a run is a
  // mnemonic when it holds >= 12 BIP39 words, OR >= 9 BIP39 words at >= 75%
  // density. Counting (rather than the old `nonBip39 <= 2` cap) is what closes
  // the leak where typos are SPREAD OUT singly: 3 isolated typos never break
  // the run yet would blow a fixed budget, leaving 9..12 real words — still
  // brute-forceable — exposed.
  final ranges = <List<int>>[]; // [start, end] char offsets to redact
  final n = words.length;
  var i = 0;
  while (i < n) {
    if (!isWord[i]) {
      i++;
      continue;
    }
    var j = i;
    var lastBip39 = i;
    var bip39count = 0;
    var consecutiveNon = 0;
    while (j < n) {
      if (j > i && !adjacent(j - 1, j)) break; // non-phrase gap ends the run
      if (isWord[j]) {
        bip39count++;
        lastBip39 = j;
        consecutiveNon = 0;
      } else if (++consecutiveNon > 2) {
        break; // 3+ non-BIP39 in a row → prose, not a phrase
      }
      j++;
    }
    // A BIP39-bounded run (first..last BIP39 word) is a mnemonic when it holds
    // >= 12 BIP39 words, OR >= 9 BIP39 words at >= 75% density. Plain prose
    // never assembles 9+ adjacent BIP39 words at that density, so it stays
    // readable; any number of spread-out typos can no longer leave the real
    // words exposed.
    final span = lastBip39 - i + 1;
    final nonBip39 = span - bip39count;
    if (bip39count >= 12 || (bip39count >= 9 && nonBip39 * 4 <= span)) {
      ranges.add([words[i].start, words[lastBip39].end]);
    }
    i = j > i ? j : i + 1;
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
