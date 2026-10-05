import 'package:bb_mobile/features/sp/data/key_value_sp_auto_scan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sp_fakes.dart';

const _storageKey = 'sp_auto_scan_enabled';

void main() {
  group('KeyValueSpAutoScanRepository', () {
    test('reads enabled before warmUp so no caller has to guess', () {
      final repo = KeyValueSpAutoScanRepository(
        storage: InMemoryKeyValueStorage(),
      );

      expect(repo.isEnabledNow, isTrue);
    });

    test('warmUp on an empty store leaves auto scan enabled', () async {
      final repo = KeyValueSpAutoScanRepository(
        storage: InMemoryKeyValueStorage(),
      );

      await repo.warmUp();

      expect(repo.isEnabledNow, isTrue);
    });

    test('warmUp reads a stored opt-out', () async {
      final storage = InMemoryKeyValueStorage();
      await storage.saveValue(key: _storageKey, value: 'false');

      final repo = KeyValueSpAutoScanRepository(storage: storage);
      await repo.warmUp();

      expect(repo.isEnabledNow, isFalse);
    });

    test('warmUp reads a stored opt-in', () async {
      final storage = InMemoryKeyValueStorage();
      await storage.saveValue(key: _storageKey, value: 'true');

      final repo = KeyValueSpAutoScanRepository(storage: storage);
      await repo.warmUp();

      expect(repo.isEnabledNow, isTrue);
    });

    test('warmUp treats an empty stored value as no choice', () async {
      final storage = InMemoryKeyValueStorage();
      await storage.saveValue(key: _storageKey, value: '');

      final repo = KeyValueSpAutoScanRepository(storage: storage);
      await repo.warmUp();

      expect(repo.isEnabledNow, isTrue);
    });

    test('warmUp treats an unreadable stored value as disabled', () async {
      final storage = InMemoryKeyValueStorage();
      await storage.saveValue(key: _storageKey, value: 'maybe');

      final repo = KeyValueSpAutoScanRepository(storage: storage);
      await repo.warmUp();

      expect(repo.isEnabledNow, isFalse);
    });

    test('save writes the opt-out and applies it right away', () async {
      final storage = InMemoryKeyValueStorage();
      final repo = KeyValueSpAutoScanRepository(storage: storage);

      await repo.save(isEnabled: false);

      expect(repo.isEnabledNow, isFalse);
      expect(await storage.getValue(_storageKey), 'false');
    });

    test('save writes the opt-in and applies it right away', () async {
      final storage = InMemoryKeyValueStorage();
      final repo = KeyValueSpAutoScanRepository(storage: storage);
      await repo.save(isEnabled: false);

      await repo.save(isEnabled: true);

      expect(repo.isEnabledNow, isTrue);
      expect(await storage.getValue(_storageKey), 'true');
    });

    test('a saved choice survives into a fresh repository', () async {
      final storage = InMemoryKeyValueStorage();
      await KeyValueSpAutoScanRepository(
        storage: storage,
      ).save(isEnabled: false);

      final reopened = KeyValueSpAutoScanRepository(storage: storage);
      await reopened.warmUp();

      expect(reopened.isEnabledNow, isFalse);
    });

    test('warmUp propagates a locked keystore', () async {
      final repo = KeyValueSpAutoScanRepository(
        storage: ThrowingKeyValueStorage(),
      );

      await expectLater(repo.warmUp(), throwsA(isA<Exception>()));
    });

    test(
      'save propagates a locked keystore after applying the choice',
      () async {
        final repo = KeyValueSpAutoScanRepository(
          storage: ThrowingKeyValueStorage(),
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
