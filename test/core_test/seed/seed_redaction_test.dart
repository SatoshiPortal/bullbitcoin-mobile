import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// Obviously-fake fixtures: the all-zero BIP39 test vector and a joke
// passphrase.
const _mnemonicWords = [
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'about',
];
const _passphrase = 'hunter2';
const _fingerprint = '73c5da0a';

void main() {
  Uint8List seedBytes() =>
      Uint8List.fromList(List<int>.generate(64, (index) => index));

  final mnemonicSeed =
      Seed.mnemonic(
            mnemonicWords: _mnemonicWords,
            passphrase: _passphrase,
            bytes: seedBytes(),
            masterFingerprint: _fingerprint,
          )
          as MnemonicSeed;
  final bytesSeed =
      Seed.bytes(bytes: seedBytes(), masterFingerprint: _fingerprint)
          as BytesSeed;

  Matcher redacted() => allOf(
    isNot(contains('abandon')),
    isNot(contains('about')),
    isNot(contains(_passphrase)),
    // The derived bytes are key material too: a dump of the raw list would
    // start with the first few elements of `seedBytes()`.
    isNot(contains('0, 1, 2, 3')),
  );

  group('mnemonic seed', () {
    test('toString redacts the words, the passphrase and the bytes', () {
      expect(mnemonicSeed.toString(), redacted());
      expect(mnemonicSeed.toString(), contains('mnemonicWords: <redacted>'));
      expect(mnemonicSeed.toString(), contains('passphrase: <redacted>'));
      expect(mnemonicSeed.toString(), contains('bytes: <redacted>'));
      // The fingerprint is the seed's public identifier and stays visible so
      // the dump is still useful.
      expect(mnemonicSeed.toString(), contains(_fingerprint));
    });

    test('a null passphrase is redacted the same way as a real one', () {
      // Printing `passphrase: null` would tell an attacker reading the logs
      // which seeds are worth attacking without one.
      final noPassphrase = Seed.mnemonic(
        mnemonicWords: _mnemonicWords,
        bytes: seedBytes(),
        masterFingerprint: _fingerprint,
      );
      expect(noPassphrase.toString(), contains('passphrase: <redacted>'));
      expect(noPassphrase.toString(), isNot(contains('null')));
    });

    test('string interpolation and collection dumps stay redacted', () {
      expect('$mnemonicSeed', redacted());
      expect([mnemonicSeed].toString(), redacted());
      expect({'seed': mnemonicSeed}.toString(), redacted());
      expect({mnemonicSeed}.toString(), redacted());
    });

    test('a thrown error wrapping the seed stays redacted', () {
      Object? caught;
      try {
        throw StateError('failed to derive from $mnemonicSeed');
      } catch (e) {
        caught = e;
      }
      expect(caught.toString(), redacted());

      try {
        throw ArgumentError.value(mnemonicSeed, 'seed', 'unsupported');
      } catch (e) {
        caught = e;
      }
      expect(caught.toString(), redacted());
    });

    test('the diagnostics tree does not carry the secrets', () {
      // Freezed mixed in `DiagnosticableTreeMixin` and generated a
      // `debugFillProperties` that added every field as a property, which put
      // the mnemonic in the widget inspector and in framework error dumps.
      expect(mnemonicSeed, isNot(isA<Diagnosticable>()));

      final node = DiagnosticsProperty<Object>('seed', mnemonicSeed);
      expect(node.toDescription(), redacted());
      expect(node.toStringDeep(), redacted());

      final error = FlutterErrorDetails(
        exception: StateError('seed failure'),
        library: 'seed',
        informationCollector: () => [DiagnosticsProperty('seed', mnemonicSeed)],
      );
      expect(error.toStringShort(), redacted());
      expect(error.toDiagnosticsNode().toStringDeep(), redacted());
    });
  });

  group('bytes seed', () {
    test('toString redacts the bytes and keeps the fingerprint', () {
      expect(bytesSeed.toString(), redacted());
      expect(bytesSeed.toString(), contains('bytes: <redacted>'));
      expect(bytesSeed.toString(), contains(_fingerprint));
    });

    test('string interpolation and collection dumps stay redacted', () {
      expect('$bytesSeed', redacted());
      expect([bytesSeed].toString(), redacted());
      expect({'seed': bytesSeed}.toString(), redacted());
    });

    test('a thrown error wrapping the seed stays redacted', () {
      Object? caught;
      try {
        throw StateError('failed to derive from $bytesSeed');
      } catch (e) {
        caught = e;
      }
      expect(caught.toString(), redacted());
    });
  });

  test('seeds do not expose their key material through equality', () {
    // Value equality over the mnemonic words (Freezed used a
    // `DeepCollectionEquality`) turns `==` into an oracle for guessing them,
    // so both variants keep identity equality. Seeds are matched on
    // `masterFingerprint` instead.
    final other = Seed.mnemonic(
      mnemonicWords: _mnemonicWords,
      passphrase: _passphrase,
      bytes: seedBytes(),
      masterFingerprint: _fingerprint,
    );
    expect(mnemonicSeed == other, isFalse);
    expect(mnemonicSeed == mnemonicSeed, isTrue);

    expect(
      bytesSeed ==
          Seed.bytes(bytes: seedBytes(), masterFingerprint: _fingerprint),
      isFalse,
    );
    expect(bytesSeed == bytesSeed, isTrue);
  });

  test('the public surface the call sites use is unchanged', () {
    expect(mnemonicSeed.mnemonicWords, _mnemonicWords);
    expect(mnemonicSeed.passphrase, _passphrase);
    expect(bytesSeed.masterFingerprint, _fingerprint);
    expect(bytesSeed.hex, startsWith('000102'));

    // Switching over the sealed hierarchy still destructures.
    final Seed seed = mnemonicSeed;
    final words = switch (seed) {
      MnemonicSeed(:final mnemonicWords) => mnemonicWords,
      BytesSeed() => const <String>[],
    };
    expect(words, _mnemonicWords);
  });
}
