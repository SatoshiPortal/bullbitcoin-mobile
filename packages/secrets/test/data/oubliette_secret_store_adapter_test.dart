import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/data/adapters/oubliette_secret_store_adapter.dart';
import 'package:secrets/src/data/datasources/hardware_key_invalidated_exception.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';

import 'fake_oubliette.dart';

void main() {
  late FakeOubliette o;
  late OublietteSecretStoreAdapter store;

  setUp(() {
    o = FakeOubliette();
    store = OublietteSecretStoreAdapter(o);
  });

  Uint8List bytes(List<int> b) => Uint8List.fromList(b);

  group('round-trip', () {
    test('store then useAndForget exposes the bytes', () async {
      await store.store('seed_a', bytes([1, 2, 3]));
      final got = await store.useAndForget(
        'seed_a',
        (b) async => Uint8List.fromList(b),
      );
      expect(got, [1, 2, 3]);
    });

    test('exists / trash / keys reflect the store', () async {
      await store.store('seed_a', bytes([9]));
      expect(await store.exists('seed_a'), isTrue);
      expect(await store.keys(), ['seed_a']);
      await store.trash('seed_a');
      expect(await store.exists('seed_a'), isFalse);
    });

    test('purge wipes everything', () async {
      await store.store('seed_a', bytes([1]));
      await store.store('seed_b', bytes([2]));
      await store.purge();
      expect(await store.keys(), isEmpty);
    });
  });

  group('null / duplicate convention', () {
    test('useAndForget on an absent key → SecretNotFoundException', () async {
      expect(
        () => store.useAndForget('missing', (b) async => b),
        throwsA(isA<SecretNotFoundException>()),
      );
    });

    test('a second store of the same key → SecretAlreadyExistsException',
        () async {
      await store.store('seed_a', bytes([1]));
      expect(
        () => store.store('seed_a', bytes([2])),
        throwsA(isA<SecretAlreadyExistsException>()),
      );
    });
  });

  group('OublietteException translation', () {
    test('AuthenticationFailed (locked) → KeychainLockedException', () async {
      o.locked = true;
      expect(
        () => store.useAndForget('seed_a', (b) async => b),
        throwsA(isA<KeychainLockedException>()),
      );
      expect(() => store.exists('seed_a'),
          throwsA(isA<KeychainLockedException>()));
    });

    test('BackendUnavailable → KeychainLockedException', () async {
      o.backendUnavailable = true;
      expect(() => store.init(), throwsA(isA<KeychainLockedException>()));
    });

    test('KeyInvalidated → HardwareKeyInvalidatedException carrying the key',
        () async {
      o.keyInvalidated = true;
      await expectLater(
        () => store.useAndForget('seed_x', (b) async => b),
        throwsA(
          isA<HardwareKeyInvalidatedException>()
              .having((e) => e.key, 'key', 'seed_x'),
        ),
      );
    });
  });

  test('capabilities() advertises hardware-backed, device-local, no sync', () {
    final c = store.capabilities();
    expect(c.hardwareBacked, isTrue);
    expect(c.thisDeviceOnly, isTrue);
    expect(c.syncable, isFalse);
  });
}
