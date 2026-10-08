import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/data/fss_datasource.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

/// The iOS cohort from 6.5.2 and earlier, whose seeds were filed under `kSecAttrAccessibleWhenUnlocked`.
///
/// The plugin puts the accessibility class in every lookup, so those items are either invisible to the package or kept in a class that a backup carries to another device. The package re-files them once, as `first_unlock_this_device`, before its first operation. Both keychain behaviours are modelled: one that filters lookups on the class, one that ignores it.
void main() {
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
  const fingerprint = '73c5da0a';
  const seedKey = 'seed_$fingerprint';
  const legacy = 'unlocked';
  const current = 'first_unlock_this_device';
  const marker = FlutterSecureStorageDatasource.rebindMarkerKey;
  const backupKey =
      '${FlutterSecureStorageDatasource.rebindBackupPrefix}$seedKey';
  final value = jsonEncode({
    'mnemonicWords': words,
    'passphrase': null,
    'runtimeType': 'mnemonic',
  });

  Secrets secretsWith(FakeSecureStoragePlatform storage) {
    storage.install();
    return Secrets(scratchDirectory: () async => '/tmp');
  }

  FakeSecureStoragePlatform legacyStore({
    bool filters = true,
    Map<String, String> extra = const {},
    Map<String, String> extraClasses = const {},
    List<Object?>? scriptedWrites,
  }) => FakeSecureStoragePlatform(
    entries: {seedKey: value, ...extra},
    accessibilityOf: {seedKey: legacy, ...extraClasses},
    filtersAccessibility: filters,
    scriptedWrites: scriptedWrites,
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    FlutterSecureStorageDatasource.debugForgetRebind();
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('a keychain that filters lookups on the class', () {
    test('a legacy seed is found, not reported missing', () async {
      final storage = legacyStore();
      final secrets = secretsWith(storage);

      final secret = ok(await secrets.fetch(Fingerprint(fingerprint)));

      expect(secret.id.hex, fingerprint);
      expect(storage.entries[seedKey], value, reason: 'same bytes');
      expect(storage.accessibilityOf![seedKey], current);
      expect(storage.entries.containsKey(backupKey), isFalse);
      expect(storage.entries.containsKey(marker), isTrue);
    });

    test('a legacy seed is listed', () async {
      final secrets = secretsWith(legacyStore());

      final listed = ok(await secrets.list());

      expect(listed.whereType<Secret>().single.id.hex, fingerprint);
    });

    test('entries outside the seed namespace keep their class', () async {
      // The app's own keys are not this package's to move.
      final storage = legacyStore(
        extra: {'pin_code': '1234'},
        extraClasses: {'pin_code': legacy},
      );
      final secrets = secretsWith(storage);

      ok(await secrets.list());

      expect(storage.accessibilityOf!['pin_code'], legacy);
      expect(storage.entries['pin_code'], '1234');
    });
  });

  test('a keychain that ignores the class: the seed still moves', () async {
    // Here the legacy item is readable all along, but filed where a backup
    // carries it to another device. Being readable is not being re-filed.
    final storage = legacyStore(filters: false);
    final secrets = secretsWith(storage);

    ok(await secrets.fetch(Fingerprint(fingerprint)));

    expect(storage.accessibilityOf![seedKey], current);
    expect(storage.entries[seedKey], value);
  });

  test('once recorded, it does not run again', () async {
    final storage = legacyStore(
      filters: false,
      extra: {marker: '1'},
      extraClasses: {marker: current},
    );
    final secrets = secretsWith(storage);

    ok(await secrets.fetch(Fingerprint(fingerprint)));

    expect(storage.accessibilityOf![seedKey], legacy);
  });

  test('not on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final storage = legacyStore(filters: false);
    final secrets = secretsWith(storage);

    ok(await secrets.fetch(Fingerprint(fingerprint)));

    expect(storage.accessibilityOf![seedKey], legacy);
    expect(storage.entries.containsKey(marker), isFalse);
  });

  group('interrupted', () {
    test('after the delete: the backup brings the seed back', () async {
      // The run stopped between deleting the original and writing it again.
      final storage = FakeSecureStoragePlatform(
        entries: {backupKey: value},
        accessibilityOf: {backupKey: current},
        filtersAccessibility: true,
      );
      final secrets = secretsWith(storage);

      ok(await secrets.fetch(Fingerprint(fingerprint)));

      expect(storage.entries[seedKey], value);
      expect(storage.accessibilityOf![seedKey], current);
      expect(storage.entries.containsKey(backupKey), isFalse);
      expect(
        storage.entries.containsKey(marker),
        isFalse,
        reason: 'backup recovery does not prove legacy listing visibility',
      );
    });

    test('after the rewrite: only the backup goes', () async {
      final storage = FakeSecureStoragePlatform(
        entries: {seedKey: value, backupKey: value},
        accessibilityOf: {seedKey: current, backupKey: current},
        filtersAccessibility: true,
      );
      final secrets = secretsWith(storage);

      ok(await secrets.fetch(Fingerprint(fingerprint)));

      expect(storage.entries[seedKey], value);
      expect(storage.entries.containsKey(backupKey), isFalse);
    });

    test('a backup that disagrees with the seed is left alone', () async {
      // Nothing this package writes produces that state, so it is not
      // resolved by guessing which value is right.
      final storage = FakeSecureStoragePlatform(
        entries: {seedKey: value, backupKey: '{"other": true}'},
        accessibilityOf: {seedKey: current, backupKey: current},
        filtersAccessibility: true,
      );
      final secrets = secretsWith(storage);

      ok(await secrets.fetch(Fingerprint(fingerprint)));

      expect(storage.entries[backupKey], '{"other": true}');
      expect(storage.entries.containsKey(marker), isFalse);
    });

    test('a write that fails is finished by the next operation', () async {
      // Backup written, original deleted, then the rewrite fails.
      final storage = legacyStore(
        scriptedWrites: [null, null, Exception('keychain write failed')],
      );
      final secrets = secretsWith(storage);

      final first = ok(await secrets.list());
      expect(first.whereType<Secret>().single.id.hex, fingerprint);
      expect(storage.entries[backupKey], value, reason: 'the value survives');
      expect(storage.entries.containsKey(marker), isFalse);

      ok(await secrets.fetch(Fingerprint(fingerprint)));

      expect(storage.entries[seedKey], value);
      expect(storage.accessibilityOf![seedKey], current);
      expect(storage.entries.containsKey(backupKey), isFalse);
      expect(
        storage.entries.containsKey(marker),
        isFalse,
        reason: 'backup recovery does not prove legacy listing visibility',
      );
    });
  });

  test('an empty legacy listing is retried by the next operation', () async {
    // A silent enumeration miss must not permanently certify migration.
    final storage = FakeSecureStoragePlatform(
      accessibilityOf: {},
      filtersAccessibility: true,
    );
    final secrets = secretsWith(storage);

    expect(ok(await secrets.list()), isEmpty);
    expect(storage.entries.containsKey(marker), isFalse);

    storage.entries[seedKey] = value;
    storage.accessibilityOf![seedKey] = legacy;
    final secret = ok(await secrets.fetch(Fingerprint(fingerprint)));

    expect(secret.id.hex, fingerprint);
    expect(storage.accessibilityOf![seedKey], current);
    expect(storage.entries.containsKey(marker), isTrue);
  });

  test(
    'recovering a backup does not certify an empty legacy listing',
    () async {
      final storage = FakeSecureStoragePlatform(
        entries: {backupKey: value},
        accessibilityOf: {backupKey: current},
        filtersAccessibility: true,
      );
      final secrets = secretsWith(storage);

      expect(
        ok(await secrets.list()).whereType<Secret>().single.id.hex,
        fingerprint,
      );
      expect(storage.entries[seedKey], value);
      expect(storage.entries.containsKey(backupKey), isFalse);
      expect(storage.entries.containsKey(marker), isFalse);

      // A previously invisible old-class item appears on the next operation.
      const laterKey = 'seed_aabbccdd';
      storage.entries[laterKey] = value;
      storage.accessibilityOf![laterKey] = legacy;
      ok(await secrets.list());

      expect(storage.entries[laterKey], value);
      expect(storage.accessibilityOf![laterKey], current);
      expect(storage.entries.containsKey(marker), isTrue);
    },
  );

  test('an empty legacy seed defers the completion marker', () async {
    final storage = legacyStore()..entries[seedKey] = '';
    final secrets = secretsWith(storage);

    ok(await secrets.list());

    expect(storage.entries.containsKey(marker), isFalse);
    storage.entries[seedKey] = value;
    ok(await secrets.fetch(Fingerprint(fingerprint)));
    expect(storage.accessibilityOf![seedKey], current);
  });

  test(
    'trash removes a pending backup so it cannot restore the seed',
    () async {
      final storage = FakeSecureStoragePlatform(
        entries: {seedKey: value, backupKey: '{"other": true}'},
        accessibilityOf: {seedKey: current, backupKey: current},
        filtersAccessibility: true,
      )..install();
      final datasource = FlutterSecureStorageDatasource();

      await datasource.trashSecret(Fingerprint(fingerprint));

      expect(storage.entries.containsKey(seedKey), isFalse);
      expect(storage.entries.containsKey(backupKey), isFalse);
      FlutterSecureStorageDatasource.debugForgetRebind();
      expect(await datasource.fetchSecret(Fingerprint(fingerprint)), isNull);
    },
  );

  test('trash keeps the seed if deleting its pending backup fails', () async {
    final storage = FakeSecureStoragePlatform(
      entries: {seedKey: value, backupKey: '{"other": true}'},
      accessibilityOf: {seedKey: current, backupKey: current},
      filtersAccessibility: true,
      scriptedWrites: [Exception('backup delete failed')],
    )..install();
    final datasource = FlutterSecureStorageDatasource();

    await expectLater(
      datasource.trashSecret(Fingerprint(fingerprint)),
      throwsA(isA<Exception>()),
    );

    expect(storage.entries[seedKey], value);
    expect(storage.entries.containsKey(backupKey), isTrue);
  });

  test(
    'a failed rewrite remains readable through its verified backup',
    () async {
      final storage = legacyStore(
        scriptedWrites: [null, null, Exception('keychain write failed')],
      );
      final secrets = secretsWith(storage);

      final secret = ok(await secrets.fetch(Fingerprint(fingerprint)));

      expect(secret.id.hex, fingerprint);
      expect(storage.entries[backupKey], value);
    },
  );

  test('a locked keychain defers it to a later operation', () async {
    final storage = legacyStore()..locked = true;
    final secrets = secretsWith(storage);

    expect(
      err(await secrets.fetch(Fingerprint(fingerprint))),
      isA<KeystoreLockedFailure>(),
    );
    expect(storage.accessibilityOf![seedKey], legacy);

    storage.locked = false;
    ok(await secrets.fetch(Fingerprint(fingerprint)));

    expect(storage.accessibilityOf![seedKey], current);
  });
}
