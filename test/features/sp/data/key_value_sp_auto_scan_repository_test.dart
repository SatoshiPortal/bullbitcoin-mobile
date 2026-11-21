import 'package:bb_mobile/features/sp/data/key_value_sp_auto_scan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/testing.dart';

import '../sp_fakes.dart';

const _storageKey = 'sp_auto_scan_enabled';

void main() {
  group('KeyValueSpAutoScanRepository', () {
    test('reads enabled before warmUp so no caller has to guess', () {
      final repo = KeyValueSpAutoScanRepository(
        storage: spKeychain(FakeSecureStoragePlatform()),
      );

      expect(repo.isEnabledNow, isTrue);
    });

    test('warmUp on an empty store leaves auto scan enabled', () async {
      final repo = KeyValueSpAutoScanRepository(
        storage: spKeychain(FakeSecureStoragePlatform()),
      );

      await repo.warmUp();

      expect(repo.isEnabledNow, isTrue);
    });

    test('warmUp reads a stored opt-out', () async {
      final storage = FakeSecureStoragePlatform();
      storage.entries[_storageKey] = 'false';

      final repo = KeyValueSpAutoScanRepository(storage: spKeychain(storage));
      await repo.warmUp();

      expect(repo.isEnabledNow, isFalse);
    });

    test('warmUp reads a stored opt-in', () async {
      final storage = FakeSecureStoragePlatform();
      storage.entries[_storageKey] = 'true';

      final repo = KeyValueSpAutoScanRepository(storage: spKeychain(storage));
      await repo.warmUp();

      expect(repo.isEnabledNow, isTrue);
    });

    test('warmUp treats an empty stored value as no choice', () async {
      final storage = FakeSecureStoragePlatform();
      storage.entries[_storageKey] = '';

      final repo = KeyValueSpAutoScanRepository(storage: spKeychain(storage));
      await repo.warmUp();

      expect(repo.isEnabledNow, isTrue);
    });

    test('warmUp treats an unreadable stored value as disabled', () async {
      final storage = FakeSecureStoragePlatform();
      storage.entries[_storageKey] = 'maybe';

      final repo = KeyValueSpAutoScanRepository(storage: spKeychain(storage));
      await repo.warmUp();

      expect(repo.isEnabledNow, isFalse);
    });

    test('save writes the opt-out and applies it right away', () async {
      final storage = FakeSecureStoragePlatform();
      final repo = KeyValueSpAutoScanRepository(storage: spKeychain(storage));

      await repo.save(isEnabled: false);

      expect(repo.isEnabledNow, isFalse);
      expect(storage.entries[_storageKey], 'false');
    });

    test('save writes the opt-in and applies it right away', () async {
      final storage = FakeSecureStoragePlatform();
      final repo = KeyValueSpAutoScanRepository(storage: spKeychain(storage));
      await repo.save(isEnabled: false);

      await repo.save(isEnabled: true);

      expect(repo.isEnabledNow, isTrue);
      expect(storage.entries[_storageKey], 'true');
    });

    test('a saved choice survives into a fresh repository', () async {
      final storage = FakeSecureStoragePlatform();
      await KeyValueSpAutoScanRepository(storage: spKeychain(storage))
          .save(isEnabled: false);

      final reopened = KeyValueSpAutoScanRepository(
        storage: spKeychain(storage),
      );
      await reopened.warmUp();

      expect(reopened.isEnabledNow, isFalse);
    });

    test('warmUp propagates a locked keystore', () async {
      final repo = KeyValueSpAutoScanRepository(
        storage: spKeychain(
          FakeSecureStoragePlatform(locked: true, writesFail: true),
        ),
      );

      await expectLater(repo.warmUp(), throwsA(isA<Exception>()));
    });

    test(
      'save propagates a locked keystore after applying the choice',
      () async {
        final repo = KeyValueSpAutoScanRepository(
          storage: spKeychain(
            FakeSecureStoragePlatform(locked: true, writesFail: true),
          ),
        );

        await expectLater(
          repo.save(isEnabled: false),
          throwsA(isA<Exception>()),
        );
        expect(repo.isEnabledNow, isFalse);
      },
    );
  });
}
