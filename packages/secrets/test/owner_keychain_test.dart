import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
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
        await secrets.accessKeychain.isPinSet(),
        isA<Ok<bool, SecretFailure>>().having((r) => r.value, 'set', true),
      );
      expect(
        await secrets.accessKeychain.verifyPin('synthetic'),
        isA<Ok<bool?, SecretFailure>>().having((r) => r.value, 'match', true),
      );
      expect(
        await secrets.accessKeychain.verifyPin('wrong'),
        isA<Ok<bool?, SecretFailure>>().having((r) => r.value, 'match', false),
      );
      final results = [
        await secrets.accessKeychain.readAttempts(),
        await secrets.accessKeychain.readLockedUntil(),
        await secrets.exchangeKeychain.read(isTestnet: false),
        await secrets.exchangeKeychain.read(isTestnet: true),
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
    final access = secrets.accessKeychain;
    await access.setPin('synthetic');
    await access.writeAttempts('2');
    await access.writeLockedUntil('42');
    await secrets.exchangeKeychain.write('main', isTestnet: false);
    await secrets.exchangeKeychain.write('test', isTestnet: true);
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
    await secrets.exchangeKeychain.delete(isTestnet: true);
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
    await secrets.accessKeychain.isPinSet();
    expect(store.optionsSeen.last, containsPair('resetOnError', 'false'));
    expect(
      store.optionsSeen.last,
      containsPair('migrateOnAlgorithmChange', 'false'),
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await secrets.accessKeychain.isPinSet();
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
          await secrets.accessKeychain.isPinSet(),
          isA<Err<bool, SecretFailure>>().having(
            (r) => r.failure,
            'locked',
            isA<KeystoreLockedFailure>(),
          ),
        );
        store.scriptedWrites.add(error);
        expect(
          await secrets.accessKeychain.deletePin(),
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
      final result = await secrets.accessKeychain.setPin('replacement');
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
