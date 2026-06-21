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

    test('does NOT over-redact ordinary prose (12+ non-BIP39 words)', () {
      const prose = 'the user tried again but the read was null after the '
          'retry loop ran out and then it simply gave up entirely here';
      // None of these are BIP39 words → must stay fully readable for debugging.
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
