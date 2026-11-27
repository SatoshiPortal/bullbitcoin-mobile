import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/data/data.dart' show OwnerKey, OwnerKeychain;
import 'package:secrets/testing.dart';

class _Store extends FakeSecureStoragePlatform {
  final optionsSeen = <Map<String, String>>[];
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) {
    optionsSeen.add(Map.of(options));
    return super.read(key: key, options: options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;
  late Secrets secrets;
  setUp(() {
    store = _Store()..install();
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => Directory.systemTemp.path,
    );
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'legacy entries remain readable without rewriting, PIN stays sealed',
    () async {
      store.entries.addAll({
        'securityKey': 'synthetic',
        'failedUnlockAttemptsKey': '4',
        'unlockLockedUntilKey': '123',
        'exchange_api_key': 'main',
        'exchange_api_key_testnet': 'test',
        'sp_backend_config': 'config',
        'sp_auto_scan_enabled': 'false',
        'swap_regtest_existing': 'swap',
        'seed_unrelated': 'untouched',
      });
      final before = Map.of(store.entries);
      expect(
        await _LegacyPinEntries().isPinSet(),
        isA<Ok<bool, SecretFailure>>().having((r) => r.value, 'set', true),
      );
      expect(
        await _LegacyPinEntries().verifyPin('synthetic'),
        isA<Ok<bool?, SecretFailure>>().having((r) => r.value, 'match', true),
      );
      expect(
        await _LegacyPinEntries().verifyPin('wrong'),
        isA<Ok<bool?, SecretFailure>>().having((r) => r.value, 'match', false),
      );
      final results = [
        await _LegacyPinEntries().readAttempts(),
        await _LegacyPinEntries().readLockedUntil(),
        await LegacyExchangeKeychainFixture().read(isTestnet: false),
        await LegacyExchangeKeychainFixture().read(isTestnet: true),
        await secrets.silentPaymentKeychain.readBackend(),
        await secrets.silentPaymentKeychain.readAutoScan(),
        await secrets.swapKeychain.read('swap_regtest_existing'),
      ];
      expect(results.map((r) => (r as Ok<String?, SecretFailure>).value), [
        '4',
        '123',
        'main',
        'test',
        'config',
        'false',
        'swap',
      ]);
      expect(store.entries, before);
    },
  );
  test('writes and deletes retain exact keys and unrelated entries', () async {
    store.entries['seed_unrelated'] = 'untouched';
    final access = _LegacyPinEntries();
    await access.setPin('synthetic');
    await access.writeAttempts('2');
    await access.writeLockedUntil('42');
    await LegacyExchangeKeychainFixture().write('main', isTestnet: false);
    await LegacyExchangeKeychainFixture().write('test', isTestnet: true);
    await secrets.silentPaymentKeychain.writeBackend('config');
    await secrets.silentPaymentKeychain.writeAutoScan('true');
    await secrets.swapKeychain.write('swap_regtest_id', 'swap');
    expect(store.entries, {
      'seed_unrelated': 'untouched',
      'securityKey': 'synthetic',
      'failedUnlockAttemptsKey': '2',
      'unlockLockedUntilKey': '42',
      'exchange_api_key': 'main',
      'exchange_api_key_testnet': 'test',
      'sp_backend_config': 'config',
      'sp_auto_scan_enabled': 'true',
      'swap_regtest_id': 'swap',
    });
    await access.deletePin();
    await access.deleteLockedUntil();
    await LegacyExchangeKeychainFixture().delete(isTestnet: true);
    await secrets.silentPaymentKeychain.deleteBackend();
    await secrets.swapKeychain.delete('swap_regtest_id');
    expect(store.entries, {
      'seed_unrelated': 'untouched',
      'failedUnlockAttemptsKey': '2',
      'exchange_api_key': 'main',
      'sp_auto_scan_enabled': 'true',
    });
    expect(
      await access.verifyPin('candidate'),
      isA<Ok<bool?, SecretFailure>>().having((r) => r.value, 'absent', null),
    );
  });
  test('swap scope rejects foreign keys before plugin access', () {
    for (final key in [
      'seed_deadbeef',
      'securityKey',
      'exchange_api_key',
      'com.bullbitcoin.secrets/dek/x/y',
      '',
      'Swap_x',
    ]) {
      expect(() => secrets.swapKeychain.read(key), throwsArgumentError);
      expect(
        () => secrets.swapKeychain.write(key, 'value'),
        throwsArgumentError,
      );
      expect(() => secrets.swapKeychain.delete(key), throwsArgumentError);
    }
    expect(store.reads, 0);
    expect(store.entries, isEmpty);
  });
  test('preserves Android and iOS plugin options', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _LegacyPinEntries().isPinSet();
    expect(store.optionsSeen.last, containsPair('resetOnError', 'false'));
    expect(
      store.optionsSeen.last,
      containsPair('migrateOnAlgorithmChange', 'false'),
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _LegacyPinEntries().isPinSet();
    expect(
      store.optionsSeen.last,
      containsPair('accessibility', 'first_unlock_this_device'),
    );
  });
  test(
    'all historical locked errors remain failures rather than absence',
    () async {
      for (final error in [
        PlatformException(code: 'security', details: -25308),
        PlatformException(code: '-25308'),
        PlatformException(code: 'security', message: 'status -25308'),
      ]) {
        store.scripted.add(error);
        expect(
          await _LegacyPinEntries().isPinSet(),
          isA<Err<bool, SecretFailure>>().having(
            (r) => r.failure,
            'locked',
            isA<KeystoreLockedFailure>(),
          ),
        );
        store.scriptedWrites.add(error);
        expect(
          await _LegacyPinEntries().deletePin(),
          isA<Err<void, SecretFailure>>().having(
            (r) => r.failure,
            'locked',
            isA<KeystoreLockedFailure>(),
          ),
        );
      }
    },
  );
  test(
    'unknown errors are sanitized without destroying the previous entry',
    () async {
      store.entries['securityKey'] = 'synthetic';
      store.scriptedWrites.add(
        PlatformException(code: 'failure', message: 'sensitive-payload'),
      );
      final result = await _LegacyPinEntries().setPin('replacement');
      expect(
        result,
        isA<Err<void, SecretFailure>>().having(
          (r) => r.failure,
          'write',
          isA<StoreSecretFailure>(),
        ),
      );
      expect(
        (result as Err<void, SecretFailure>).failure.logMessage,
        isNot(contains('sensitive-payload')),
      );
      expect(store.entries['securityKey'], 'synthetic');
    },
  );
}

/// The legacy PIN entries as the import and the removal read them. Not a public capability.
final class _LegacyPinEntries {
  final _store = OwnerKeychain();
  _LegacyPinEntries();

  Future<Result<bool, SecretFailure>> isPinSet() async =>
      (await _store.read(OwnerKey.pin)).map((pin) => pin != null);

  /// Null means absent; false means an existing PIN did not match.
  Future<Result<bool?, SecretFailure>> verifyPin(String candidate) async =>
      (await _store.read(OwnerKey.pin))
          .map((pin) => pin == null ? null : pin == candidate);
  Future<Result<void, SecretFailure>> setPin(String pin) =>
      _store.write(OwnerKey.pin, pin);
  Future<Result<void, SecretFailure>> deletePin() =>
      _store.delete(OwnerKey.pin);
  Future<Result<String?, SecretFailure>> readAttempts() =>
      _store.read(OwnerKey.attempts);
  Future<Result<void, SecretFailure>> writeAttempts(String value) =>
      _store.write(OwnerKey.attempts, value);
  Future<Result<String?, SecretFailure>> readLockedUntil() =>
      _store.read(OwnerKey.lockedUntil);
  Future<Result<void, SecretFailure>> writeLockedUntil(String value) =>
      _store.write(OwnerKey.lockedUntil, value);
  Future<Result<void, SecretFailure>> deleteLockedUntil() =>
      _store.delete(OwnerKey.lockedUntil);
}
