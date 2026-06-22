import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/domain/log_sanitizer.dart';

void main() {
  group('sanitizeLog', () {
    test('null / empty → empty string', () {
      expect(sanitizeLog(null), '');
      expect(sanitizeLog(''), '');
    });

    test('redacts a 64-hex seed/key blob', () {
      const hex =
          '32255e6651db67fa5b5a44240b6a5d2189cb58666bcc3830c35aff5a2b01b84f';
      final out = sanitizeLog('bad key: $hex while signing');
      expect(out, contains('[REDACTED_HEX]'));
      expect(out, isNot(contains(hex)));
    });

    test('preserves an 8-hex fingerprint (public)', () {
      final out = sanitizeLog('seed deadbeef not found');
      expect(out, contains('deadbeef'));
    });

    test('redacts a 0x-prefixed 64-hex blob (leading \\b would miss it)', () {
      // `0x` makes `0`/`x` word chars, so a leading `\b` anchor fails to match
      // and the secret hex would leak in clear.
      const hex =
          '32255e6651db67fa5b5a44240b6a5d2189cb58666bcc3830c35aff5a2b01b84f';
      final out = sanitizeLog('key=0x$hex end');
      expect(out, contains('[REDACTED_HEX]'));
      expect(out, isNot(contains(hex)));
    });

    test('redacts a 12-word mnemonic phrase', () {
      const phrase =
          'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';
      final out = sanitizeLog('invalid mnemonic: $phrase');
      expect(out, contains('[REDACTED_MNEMONIC]'));
      expect(out, isNot(contains('zoo zoo')));
    });

    test('redacts a 24-word mnemonic phrase', () {
      final words = List.filled(24, 'abandon').join(' ');
      final out = sanitizeLog('phrase=$words');
      expect(out, contains('[REDACTED_MNEMONIC]'));
      expect(out, isNot(contains('abandon abandon')));
    });

    test('redacts a CAPITALIZED, COMMA-separated phrase (raw-input echo)', () {
      const phrase =
          'Zoo, zoo, zoo, zoo, zoo, zoo, zoo, zoo, zoo, zoo, zoo, Wrong';
      final out = sanitizeLog('invalid mnemonic: $phrase');
      expect(out, contains('[REDACTED_MNEMONIC]'));
      expect(out.toLowerCase(), isNot(contains('zoo, zoo')));
    });

    test('redacts an UPPERCASE hex blob', () {
      const hex =
          '32255E6651DB67FA5B5A44240B6A5D2189CB58666BCC3830C35AFF5A2B01B84F';
      final out = sanitizeLog('key=$hex');
      expect(out, contains('[REDACTED_HEX]'));
      expect(out, isNot(contains(hex)));
    });

    test('redacts a tprv (testnet xprv) too', () {
      const tprv =
          'tprv8ZgxMBicQKsPeDgjzfV8mP1c3J5p3aQ6zR1Z6ZcZ7m8aF7m9aF7m9aF7m9aF7m9aF7m9aF7m9aF7m9aF7m9aF7m9aF7m9aF7m9';
      final out = sanitizeLog('bad key $tprv end');
      expect(out, contains('[REDACTED_XPRV]'));
    });

    test('redacts an UPPERCASE XPRV (case-insensitive tag match)', () {
      const xprv =
          'XPRV9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi';
      final out = sanitizeLog('failed to parse $xprv here');
      expect(out, contains('[REDACTED_XPRV]'));
      expect(out, isNot(contains(xprv)));
    });

    test('redacts an extended private key', () {
      const xprv =
          'xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi';
      final out = sanitizeLog('failed to parse $xprv here');
      expect(out, contains('[REDACTED_XPRV]'));
      expect(out, isNot(contains(xprv)));
    });

    test('leaves an ordinary message untouched', () {
      expect(sanitizeLog('keychain is locked'), 'keychain is locked');
    });

    test('redacts the at-rest s1: sealed blob (the base64 mnemonic JSON)', () {
      // The format FssSecretStoreAdapter writes; a decode error can echo it.
      const blob =
          's1:eyJraW5kIjoibW5lbW9uaWMiLCJ3b3JkcyI6WyJ6b28iLCJ3cm9uZyJdfQ==';
      final out = sanitizeLog('FormatException reading $blob from store');
      expect(out, contains('[REDACTED_SEALED_BLOB]'));
      expect(out, isNot(contains('eyJraW5')));
    });

    test('does NOT redact ordinary base64 without the s1: tag', () {
      const msg = 'payload: SGVsbG8gd29ybGQgYmFzZTY0IGRhdGE';
      expect(sanitizeLog(msg), msg);
    });

    test('does NOT over-redact ordinary prose (12+ non-BIP39 words)', () {
      const prose = 'the user tried again but the read was null after the '
          'retry loop ran out and then it simply gave up entirely here';
      // None of these are BIP39 words → must stay fully readable for debugging.
      expect(sanitizeLog(prose), prose);
    });

    test('redacts a 12-word phrase with ONE typo word (no partial leak)', () {
      // A mistyped/checksum-failing word must not let the other 11 real words
      // leak — 11/12 BIP39 words is brute-forceable.
      const phrase =
          'zoo zoo zoo zoo zoo TYPOWORD zoo zoo zoo zoo zoo wrong';
      final out = sanitizeLog('invalid mnemonic: $phrase');
      expect(out, contains('[REDACTED_MNEMONIC]'));
      expect(out, isNot(contains('zoo zoo')));
      expect(out, isNot(contains('TYPOWORD')));
    });

    test('redacts a 12-word phrase with THREE spread-out typos (no leak)', () {
      // The leak the count-based rule closes: 3 isolated typos never break the
      // adjacency run, but a fixed `nonBip39 <= 2` budget would have left all
      // 12 real BIP39 words in cleartext (brute-forceable).
      const phrase =
          'zoo zoo zoo XX zoo zoo YY zoo zoo ZZ zoo zoo zoo';
      // Trailing marker is digit-guarded so it is not word-adjacent to the run.
      final out = sanitizeLog('bad mnemonic: $phrase 9stopmarker');
      expect(out, contains('[REDACTED_MNEMONIC]'));
      expect(out, isNot(contains('zoo zoo')));
      expect(out, isNot(contains('XX')));
      expect(out, contains('9stopmarker')); // trailing prose survives
    });

    test('redacts a 12-word phrase with typos reducing it to 9 BIP39 words', () {
      // 3 of the 12 words mistyped -> only 9 real BIP39 words, but at 9/12=75%
      // density it is still a mnemonic and must not leak.
      const phrase =
          'zoo zoo zoo AAA zoo zoo BBB zoo zoo CCC zoo zoo';
      final out = sanitizeLog('phrase: $phrase');
      expect(out, contains('[REDACTED_MNEMONIC]'));
      expect(out, isNot(contains('zoo zoo')));
    });

    test('still leaves ordinary prose readable (no over-redaction)', () {
      const prose = 'the user could not load the wallet after the recent '
          'update so they tried again twice and then gave up here';
      expect(sanitizeLog(prose), prose);
    });

    test('redacts a JSON-list-formatted mnemonic (the ","-separator leak)', () {
      // _toMap stores words as a JSON list; if an error echoes that raw JSON,
      // the words are separated by `","` — must still be redacted.
      final words = List.filled(12, 'abandon').join('","');
      final out = sanitizeLog('decode failed: ["$words"] bad');
      expect(out, contains('[REDACTED_MNEMONIC]'));
      expect(out, isNot(contains('abandon","abandon')));
    });

    test('redacts a real phrase even when embedded in prose', () {
      // Digit-guarded boundaries ("log99", "7tail") break word-adjacency (a
      // digit is neither a word-letter nor a separator), so they survive.
      const msg = 'log99 zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo '
          'zoo wrong 7tail';
      final out = sanitizeLog(msg);
      expect(out, contains('[REDACTED_MNEMONIC]'));
      expect(out, contains('log99'));
      expect(out, contains('7tail'));
      expect(out, isNot(contains('zoo zoo')));
    });
  });
}
