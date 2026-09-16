import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/data/data.dart';
import 'package:secrets/src/domain/domain.dart' show describeSafely;

import 'fake_secure_storage_platform.dart';
import 'result_helpers.dart';

/// A failure must never carry a word out of the package.
///
/// `bip39_mnemonic` names the offending word in its exceptions —
/// `Mnemonic word "<word>" does not exist`, and the checksum variant
/// names the last word. Those exceptions reach the generic catch, whose
/// text becomes a `SecretFailure.logMessage` that callers print and that
/// crash reporting receives.
void main() {
  Secrets secretsWith(FakeSecureStoragePlatform storage) {
    storage.install();
    return Secrets(scratchDirectory: () async => '.');
  }

  group('describeSafely', () {
    test('keeps the type and drops the message', () {
      expect(
        describeSafely(const FormatException('mnemonic word "zebra" is bad')),
        'FormatException',
      );
      expect(describeSafely(ArgumentError('secret stuff')), 'ArgumentError');
      expect(describeSafely(StateError('zebra')), isNot(contains('zebra')));
    });
  });

  group('a bad word never reaches the caller', () {
    // The checksum exception names the last word, so this is the one
    // that would leak it.
    const wrongChecksum = [
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
      'zebra',
    ];

    test('idOf returns a failure rather than throwing', () async {
      // It used to return a bare Future, so the exception escaped
      // uncaught — with the word in it.
      final result = await secretsWith(
        FakeSecureStoragePlatform(),
      ).idOf(words: wrongChecksum);

      expect(result, isA<Err<Fingerprint, SecretFailure>>());
      final failure = (result as Err<Fingerprint, SecretFailure>).failure;
      expect(failure.toString(), isNot(contains('zebra')));
    });

    test('import fails without naming the word', () async {
      final result = await secretsWith(
        FakeSecureStoragePlatform(),
      ).import(words: wrongChecksum);

      final failure = (result as Err<Secret, SecretFailure>).failure;
      expect(failure.toString(), isNot(contains('zebra')));
    });

    test(
      'reading a corrupt entry never quotes it back',
      () async {
        // The stored value is the secret itself, so a decode failure must
        // not be echoed.
        final storage = FakeSecureStoragePlatform(
          entries: {
            'seed_73c5da0a': jsonEncode({
              'mnemonicWords': ['abandon', 'zebra'],
              'passphrase': 'hunter2',
              'runtimeType': 'mnemonic',
            }),
          },
        );

        final result = await secretsWith(
          storage,
        ).fetch(Fingerprint('73c5da0a'));

        final failure = (result as Err<Secret, SecretFailure>).failure;
        for (final secret in ['zebra', 'hunter2', 'abandon']) {
          expect(failure.toString(), isNot(contains(secret)), reason: secret);
        }
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });

  test('a corrupt entry is skipped, not surfaced as a wallet', () async {
    // Lazily-cast lists used to decode fine and appear in a listing with
    // a plausible word count, failing only much later.
    final storage = FakeSecureStoragePlatform(
      entries: {
        'seed_deadbeef': jsonEncode({
          'mnemonicWords': [1, 2, 3],
          'passphrase': null,
          'runtimeType': 'mnemonic',
        }),
      },
    );

    storage.install();
    final repo = SecretRepository();

    expect(ok(await repo.describeAll()), isEmpty);
  });

  redactionOfStoredContent();
}

/// Stored content never reaches a failure's text.
///
/// A module-key envelope is untrusted input — on Linux and Windows any
/// process of the same user can rewrite one. Its fields must never be
/// quoted by the parser that refuses it, or a stored sentinel would
/// travel into `DatabaseKeyCorruptFailure.logMessage` and from there
/// into logs. Written after exactly that was observed: the typed path
/// for a corrupt module key preserved `FormatException.message`, and
/// `KeyModel.fromJson` used to interpolate the field it rejected.
void redactionOfStoredContent() {
  for (final field in ['kind', 'name', 'v']) {
    test('a sentinel stored in "$field" does not reach the failure', () async {
      const storageKey = 'com.bullbitcoin.secrets/dek/probe/main';
      const sentinel = 'SYNTHETIC_STORED_SENTINEL';
      final envelope = <String, dynamic>{
        'v': 1,
        'kind': 'dek',
        'name': storageKey,
        'bytes': '01' * 32,
        'createdAt': '2026-09-15T00:00:00.000Z',
      }..[field] = sentinel;
      final storage = FakeSecureStoragePlatform(
        entries: {storageKey: jsonEncode(envelope)},
      )..install();

      final result = await Secrets(
        scratchDirectory: () async => '/tmp',
      ).databaseKey(package: 'probe', name: 'main');

      final failure = (result as Err<DatabaseKey, SecretFailure>).failure;
      expect(failure, isA<DatabaseKeyCorruptFailure>());
      expect(failure.logMessage, isNot(contains(sentinel)));
      expect(failure.toString(), isNot(contains(sentinel)));
      expect(
        storage.entries[storageKey],
        isNotNull,
        reason: 'kept, not replaced',
      );
    });
  }

  test(
    'a sentinel stored as the seed discriminator does not reach the failure',
    () async {
      const sentinel = 'SYNTHETIC_STORED_SENTINEL';
      FakeSecureStoragePlatform(
        entries: {
          'seed_00000000': jsonEncode({
            'mnemonicWords': List.filled(12, 'abandon'),
            'passphrase': null,
            'runtimeType': sentinel,
          }),
        },
      ).install();

      final result = await Secrets(
        scratchDirectory: () async => '/tmp',
      ).fetch(Fingerprint('00000000'));

      final failure = (result as Err<Secret, SecretFailure>).failure;
      expect(failure, isA<SecretFetchFailure>());
      expect(failure.logMessage, isNot(contains(sentinel)));
    },
  );
}
