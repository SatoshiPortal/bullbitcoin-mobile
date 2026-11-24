import 'package:backups/testing.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'dart:io';

import '../../../support/inventory_fixture.dart';

class _Environment implements ActiveEnvironmentReader {
  @override
  Future<Result<Environment, PreferencesFailure>>
  readActiveEnvironment() async => const Ok(Environment.mainnet);
}

void main() {
  setUp(() => FakeSecureStoragePlatform().install());

  test('an empty bitcoin inventory produces a distinct failure', () async {
    final directory = await Directory.systemTemp.createTemp(
      'backup-inventory-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final fixture = await InventoryFixture.open(directory);
    addTearDown(fixture.close);
    final result = await LoadWalletsForNetworkUsecase(
      fixture.inventory,
      _Environment(),
      (_) => fail('No backup records should be queried'),
    ).execute();
    expect(
      result,
      isA<Err<List<BackupWallet>, TestWalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<TestWalletBackupNoWalletsFailure>(),
      ),
    );
  });

  test('an unavailable inventory produces a typed failure', () async {
    final directory = await Directory.systemTemp.createTemp(
      'backup-inventory-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final fixture = await InventoryFixture.open(directory);
    await fixture.close();
    final result = await LoadWalletsForNetworkUsecase(
      fixture.inventory,
      _Environment(),
      (_) => fail('No backup records should be queried'),
    ).execute();
    expect(
      result,
      isA<Err<List<BackupWallet>, TestWalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<TestWalletBackupWalletsUnavailableFailure>(),
      ),
    );
  });

  group('GetSecretFromFingerprintUsecase', () {
    const words = [
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

    test('returns the handle on success, never the words', () async {
      FakeSecureStoragePlatform().install();
      final secrets = Secrets(scratchDirectory: () async => '/tmp');
      final stored = (await secrets.import(
        words: words,
        language: bip39.Language.english,
      )) as Ok<Secret, SecretFailure>;
      final fingerprint = stored.value.id.hex;

      final result = await GetSecretFromFingerprintUsecase(secrets: secrets)
          .execute(fingerprint);

      final secret = (result as Ok<Secret, TestWalletBackupFailure>).value;
      expect(secret.id.hex, fingerprint);
      expect(secret.toString(), isNot(contains('abandon')));
    });

    test('drops an unreadable entry\'s reason entirely rather than carrying '
        'it into a state-resident failure', () async {
      const fingerprint = '73c5da0a';
      FakeSecureStoragePlatform(
        entries: {'seed_$fingerprint': 'not json at all'},
      ).install();

      final result = await GetSecretFromFingerprintUsecase(
        secrets: Secrets(scratchDirectory: () async => '/tmp'),
      ).execute(fingerprint);

      switch (result) {
        case Ok():
          fail('an unreadable entry must not be reported as a secret');
        case Err(:final failure):
          expect(failure, isA<TestWalletBackupSeedUnavailableFailure>());
          // The seed path is the one place where even logMessage is too far
          // to carry a raw reason.
          expect(failure.logMessage, isNull);
      }
    });
  });
}
