import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

void main() {
  late FakeSecureStoragePlatform storage;
  late AppUnlockCredential pin;

  setUp(() {
    storage = FakeSecureStoragePlatform().install();
    pin = Secrets(
      scratchDirectory: () async => '/tmp/pr2938-pin-test',
    ).appUnlockCredential;
  });

  test(
    'reads the existing key without rewriting it or touching seeds',
    () async {
      storage.entries.addAll({
        'securityKey': '123456',
        'seed_deadbeef': 'untouched',
      });
      expect((await pin.exists() as Ok).value, isTrue);
      expect((await pin.verify('123456') as Ok).value, isTrue);
      expect((await pin.verify('654321') as Ok).value, isFalse);
      expect(storage.entries, {
        'securityKey': '123456',
        'seed_deadbeef': 'untouched',
      });
    },
  );

  test('sets and deletes only the historical PIN key', () async {
    storage.entries['seed_deadbeef'] = 'untouched';
    expect((await pin.exists() as Ok).value, isFalse);
    expect(await pin.set('123456'), isA<Ok>());
    expect(storage.entries['securityKey'], '123456');
    expect(await pin.delete(), isA<Ok>());
    expect(storage.entries, {'seed_deadbeef': 'untouched'});
    expect(
      (await pin.verify('123456') as Err).failure,
      isA<SecretNotFoundFailure>(),
    );
  });

  test('locked reads and refused writes remain failures', () async {
    storage.entries['securityKey'] = '123456';
    storage.locked = true;
    expect((await pin.exists() as Err).failure, isA<KeystoreLockedFailure>());
    expect(
      (await pin.verify('123456') as Err).failure,
      isA<KeystoreLockedFailure>(),
    );
    storage.locked = false;
    storage.writesFail = true;
    expect(
      (await pin.set('654321') as Err).failure,
      isA<KeystoreLockedFailure>(),
    );
    expect((await pin.delete() as Err).failure, isA<KeystoreLockedFailure>());
    expect(storage.entries['securityKey'], '123456');
  });

  test(
    'uses the former iOS accessibility class without seed rebinding',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      storage = FakeSecureStoragePlatform(
        entries: {'securityKey': '123456'},
        accessibilityOf: {'securityKey': 'first_unlock_this_device'},
        filtersAccessibility: true,
      ).install();
      expect((await pin.verify('123456') as Ok).value, isTrue);
      expect(await pin.set('654321'), isA<Ok>());
      expect(
        storage.accessibilityOf!['securityKey'],
        'first_unlock_this_device',
      );
      expect(storage.entries.keys, ['securityKey']);
    },
  );
}
