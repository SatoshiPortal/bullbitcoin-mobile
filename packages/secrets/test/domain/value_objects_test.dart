import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/value_objects/ark_secret.dart';
import 'package:secrets/src/domain/value_objects/backup.dart';
import 'package:secrets/src/domain/value_objects/bip85_types.dart';
import 'package:secrets/src/domain/value_objects/descriptors.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_length.dart';
import 'package:secrets/src/domain/value_objects/psbt.dart';
import 'package:secrets/src/domain/value_objects/seed_info.dart';

void main() {
  group('validation (throws ArgumentError on bad input — programmer bug)', () {
    test('Xpub rejects empty', () {
      expect(() => Xpub(value: '', type: XpubType.zpub), throwsArgumentError);
    });
    test('BitcoinDescriptor rejects empty parts', () {
      expect(() => BitcoinDescriptor(external: '', internal: 'x'),
          throwsArgumentError);
      expect(() => BitcoinDescriptor(external: 'x', internal: ''),
          throwsArgumentError);
    });
    test('LiquidDescriptor rejects empty', () {
      expect(() => LiquidDescriptor(''), throwsArgumentError);
    });
    test('BackupKey accepts > 32 bytes', () {
      expect(BackupKey(Uint8List(64)).bytes.length, 64);
    });
    test('Psbt rejects non-base64', () {
      expect(() => Psbt('not base64!!!'), throwsArgumentError);
    });
    test('Psbt accepts valid base64', () {
      expect(Psbt('cHNidP8=').base64, 'cHNidP8=');
    });
    test('BackupKey rejects < 32 bytes', () {
      expect(() => BackupKey(Uint8List(16)), throwsArgumentError);
      expect(BackupKey(Uint8List(32)).bytes.length, 32);
    });
    test('ArkSecret requires exactly 32 bytes', () {
      expect(() => ArkSecret(Uint8List(16)), throwsArgumentError);
      expect(ArkSecret(Uint8List(32)), isNotNull);
    });
    test('MnemonicLength.fromCount', () {
      expect(MnemonicLength.fromCount(12), MnemonicLength.words12);
      expect(MnemonicLength.fromCount(24), MnemonicLength.words24);
      expect(() => MnemonicLength.fromCount(15), throwsArgumentError);
    });
  });

  group('Bip85', () {
    test('application numbers', () {
      expect(Bip85Application.bip39.number, 39);
      expect(Bip85Application.hex.number, 128169);
      expect(Bip85Application.recoverbull.number, 1608);
    });
    test('path round-trips with/without m/ and exposes appNumber/index', () {
      final a = Bip85Path("m/39'/0'/12'/0'");
      final b = Bip85Path("39'/0'/12'/0'");
      expect(a, b);
      expect(a.appNumber, 39);
      expect(a.index, 0);
    });
  });

  group('SECURITY: secret-bearing toString is redacted', () {
    test('Bip85Derivation.toString omits the words', () {
      final d = Bip85Derivation(
        path: Bip85Path("39'/0'/12'/0'"),
        length: MnemonicLength.words12,
        words: const ['zoo', 'zoo', 'wrong'],
      );
      expect(d.toString(), isNot(contains('zoo')));
      expect(d.toString(), isNot(contains('wrong')));
      expect(d.words, hasLength(3)); // internal accessor still works in-package
    });

    test('Bip85HexResult.toString omits the hex', () {
      const hex = 'deadbeefdeadbeefdeadbeefdeadbeef';
      final r = Bip85HexResult(path: Bip85Path("128169'/0'"), hex: hex);
      expect(r.toString(), isNot(contains(hex)));
      expect(r.hexForView, hex);
    });

    test('BackupKey.toString omits the bytes', () {
      final k = BackupKey(Uint8List.fromList(List.filled(32, 7)));
      expect(k.toString(), isNot(contains('7, 7')));
    });

    test('ArkSecret.toString omits the bytes', () {
      final s = ArkSecret(Uint8List.fromList(List.filled(32, 9)));
      expect(s.toString(), 'ArkSecret(32 bytes)');
    });

    test('LiquidDescriptor.toString omits the ct descriptor (blinding key)', () {
      const ct = 'ct(slip77(deadbeefblindingkey),elwpkh(xpubABC))';
      final d = LiquidDescriptor(ct);
      expect(d.toString(), isNot(contains('slip77')));
      expect(d.toString(), isNot(contains('deadbeefblindingkey')));
      expect(d.ctDescriptor, ct); // value still accessible for watch-only use
    });
  });

  group('SeedInfo is non-secret metadata', () {
    test('carries fingerprint, wordCount, passphrase flag, language', () {
      final info = SeedInfo(
        fingerprint: Fingerprint('deadbeef'),
        wordCount: 12,
        hasPassphrase: true,
        language: 'english',
      );
      expect(info.fingerprint.hex, 'deadbeef');
      expect(info.wordCount, 12);
      expect(info.hasPassphrase, isTrue);
      expect(info.language, 'english');
    });
  });
}
