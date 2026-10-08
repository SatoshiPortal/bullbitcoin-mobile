import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

void main() {
  late FakeSecureStoragePlatform storage;
  late ApplicationStorage application;

  setUp(() {
    storage = FakeSecureStoragePlatform().install();
    application = Secrets(
      scratchDirectory: () async => '/tmp/pr2938-storage-test',
    ).applicationStorage;
  });

  test('refuses custody keys synchronously before any plugin read', () {
    for (final key in [
      'seed_deadbeef',
      'com.bullbitcoin.secrets/dek/swaps/main',
      'securityKey',
    ]) {
      expect(() => application.read(key), throwsArgumentError);
      expect(
        () => application.write(key: key, value: 'dummy'),
        throwsArgumentError,
      );
      expect(() => application.delete(key), throwsArgumentError);
      expect(() => application.contains(key), throwsArgumentError);
    }
    expect(storage.reads, 0);
    expect(storage.entries, isEmpty);
  });

  test(
    'preserves historical application entries and excludes custody listings',
    () async {
      storage.entries.addAll({
        'swap_key_123': 'dummy',
        'seed_deadbeef': 'hidden',
        'securityKey': '123456',
      });
      expect((await application.readAll() as Ok).value, {
        'swap_key_123': 'dummy',
      });
      expect((await application.read('swap_key_123') as Ok).value, 'dummy');
      expect((await application.contains('swap_key_123') as Ok).value, isTrue);
      expect(
        await application.write(key: 'exchange_api_key', value: 'dummy-key'),
        isA<Ok>(),
      );
      expect(await application.delete('swap_key_123'), isA<Ok>());
      expect(storage.entries, {
        'exchange_api_key': 'dummy-key',
        'seed_deadbeef': 'hidden',
        'securityKey': '123456',
      });
    },
  );

  test('locked storage remains a failure for reads and mutations', () async {
    storage.locked = true;
    expect(
      (await application.read('swap_key_123') as Err).failure,
      isA<KeystoreLockedFailure>(),
    );
    expect(
      (await application.readAll() as Err).failure,
      isA<KeystoreLockedFailure>(),
    );
    storage.writesFail = true;
    expect(
      (await application.write(key: 'swap_key_123', value: 'dummy') as Err)
          .failure,
      isA<KeystoreLockedFailure>(),
    );
    expect(
      (await application.delete('swap_key_123') as Err).failure,
      isA<KeystoreLockedFailure>(),
    );
  });

  test('foreign storage errors cannot expose the stored value', () async {
    storage.scripted.add(
      PlatformException(code: 'dummy', message: 'sensitive-test-value'),
    );
    final failure =
        (await application.read('swap_key_123') as Err).failure
            as SecretFailure;
    expect(failure, isA<FetchSecretFailure>());
    expect(failure.logMessage, 'PlatformException');
    expect(failure.logMessage, isNot(contains('sensitive-test-value')));
  });
}
