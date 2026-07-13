import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements KeyValueStorageDatasource<String> {}

void main() {
  late _MockStorage storage;
  late PinCodeRepository repository;

  const key = 'securityKey';
  const markerKey = 'securityKeyAccessibilityHealedV1';
  const backupKey = 'securityKeyHealBackupV1';
  const pin = '040593';

  setUp(() {
    storage = _MockStorage();
    repository = PinCodeRepository(storage);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('isPinCodeSet', () {
    test('lets KeychainLockedException bubble up unchanged', () async {
      // This is a load-bearing, startup-gating read: AppStartupBloc has a
      // dedicated typed catch for KeychainLockedException that stays on the
      // splash screen and retries once the device unlocks. Swallowing it
      // into a generic PinCodeFailure here (as the code used to) makes that
      // retry path unreachable and the app gets stuck on a permanent
      // "Startup Error" screen instead.
      when(
        () => storage.getValue(any()),
      ).thenThrow(const KeychainLockedException());

      await expectLater(
        repository.isPinCodeSet(),
        throwsA(isA<KeychainLockedException>()),
      );
    });

    test(
      'returns Err(PinCodeUnexpectedFailure) for any other failure',
      () async {
        when(() => storage.getValue(any())).thenThrow(Exception('disk error'));

        final result = await repository.isPinCodeSet();

        expect(result, isA<Err<bool, PinCodeFailure>>());
      },
    );
  });

  group('heal backup crash-safety', () {
    setUp(() {
      when(
        () => storage.saveValue(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(() => storage.deleteValue(any())).thenAnswer((_) async {});
    });

    test(
      'restores the PIN from the heal backup when the primary key is '
      'missing, so a crash mid-heal never reports "no PIN set"',
      () async {
        when(() => storage.getValue(key)).thenAnswer((_) async => null);
        when(() => storage.getValue(backupKey)).thenAnswer((_) async => pin);

        final result = await repository.isPinCodeSet();

        expect(
          result,
          isA<Ok<bool, PinCodeFailure>>().having((r) => r.value, 'value', true),
        );
        verify(() => storage.saveValue(key: key, value: pin)).called(1);
      },
    );

    test(
      'returns false when neither the primary key nor the backup exist',
      () async {
        when(() => storage.getValue(key)).thenAnswer((_) async => null);
        when(() => storage.getValue(backupKey)).thenAnswer((_) async => null);

        final result = await repository.isPinCodeSet();

        expect(
          result,
          isA<Ok<bool, PinCodeFailure>>().having(
            (r) => r.value,
            'value',
            false,
          ),
        );
      },
    );

    test(
      'a failed restore write still returns the correct pin for this call',
      () async {
        when(() => storage.getValue(key)).thenAnswer((_) async => null);
        when(() => storage.getValue(backupKey)).thenAnswer((_) async => pin);
        when(
          () => storage.saveValue(key: key, value: pin),
        ).thenThrow(Exception('boom'));

        final result = await repository.isPinCodeSet();

        expect(
          result,
          isA<Ok<bool, PinCodeFailure>>().having((r) => r.value, 'value', true),
        );
      },
    );

    test('setPinCode clears a stale heal backup', () async {
      await repository.setPinCode(pin);

      verify(() => storage.saveValue(key: key, value: pin)).called(1);
      verify(() => storage.deleteValue(backupKey)).called(1);
    });

    test(
      'deletePinCode clears the heal backup BEFORE the live key, so a '
      'crash between the two never leaves key-absent/backup-present — '
      'the exact state that would resurrect the old pin',
      () async {
        await repository.deletePinCode();

        verifyInOrder([
          () => storage.deleteValue(backupKey),
          () => storage.deleteValue(key),
        ]);
      },
    );

    test(
      'a backup-delete failure is retried once, and the live key is still '
      'deleted once the backup is confirmed gone',
      () async {
        var backupDeleteAttempts = 0;
        when(() => storage.deleteValue(backupKey)).thenAnswer((_) async {
          backupDeleteAttempts++;
          if (backupDeleteAttempts == 1) throw Exception('boom');
        });

        final result = await repository.deletePinCode();

        expect(result, isA<Ok<Null, PinCodeFailure>>());
        verify(() => storage.deleteValue(backupKey)).called(2);
        verify(() => storage.deleteValue(key)).called(1);
      },
    );

    test(
      'a backup-delete failure twice refuses to delete the live key, so '
      'the pin is never left resurrectable',
      () async {
        when(
          () => storage.deleteValue(backupKey),
        ).thenThrow(Exception('boom'));

        final result = await repository.deletePinCode();

        expect(result, isA<Err<Null, PinCodeFailure>>());
        verify(() => storage.deleteValue(backupKey)).called(2);
        verifyNever(() => storage.deleteValue(key));
      },
    );
  });

  group('legacy keychain accessibility heal', () {
    void stubStoredPin({String? markerValue}) {
      when(() => storage.getValue(key)).thenAnswer((_) async => pin);
      when(
        () => storage.getValue(markerKey),
      ).thenAnswer((_) async => markerValue);
      when(() => storage.deleteValue(any())).thenAnswer((_) async {});
      when(
        () => storage.saveValue(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
    }

    test('on iOS with no healed marker, a successful read backs up the pin, '
        'deletes and re-saves it so the item is re-added under the current '
        'accessibility class, writes the marker, then clears the backup', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      stubStoredPin();

      final result = await repository.isPinCodeSet();

      expect(
        result,
        isA<Ok<bool, PinCodeFailure>>().having((r) => r.value, 'value', true),
      );
      verifyInOrder([
        () => storage.getValue(markerKey),
        () => storage.saveValue(key: backupKey, value: pin),
        () => storage.deleteValue(key),
        () => storage.saveValue(key: key, value: pin),
        () => storage.saveValue(key: markerKey, value: '1'),
        () => storage.deleteValue(backupKey),
      ]);
    });

    test('runs on verifyPinCode success path too', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      stubStoredPin();

      final result = await repository.verifyPinCode(pin);

      expect(
        result,
        isA<Ok<bool, PinCodeFailure>>().having((r) => r.value, 'value', true),
      );
      verify(() => storage.deleteValue(key)).called(1);
      verify(() => storage.saveValue(key: key, value: pin)).called(1);
      verify(() => storage.saveValue(key: markerKey, value: '1')).called(1);
    });

    test('does not run when the healed marker is already present', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      stubStoredPin(markerValue: '1');

      final result = await repository.isPinCodeSet();

      expect(
        result,
        isA<Ok<bool, PinCodeFailure>>().having((r) => r.value, 'value', true),
      );
      verifyNever(() => storage.deleteValue(any()));
      verifyNever(
        () => storage.saveValue(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      );
    });

    test('runs only once per repository instance', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      stubStoredPin();

      await repository.isPinCodeSet();
      await repository.isPinCodeSet();
      await repository.verifyPinCode(pin);

      verify(() => storage.getValue(markerKey)).called(1);
      verify(() => storage.deleteValue(key)).called(1);
      verify(() => storage.saveValue(key: key, value: pin)).called(1);
    });

    test('does not run when no pin is stored', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(() => storage.getValue(key)).thenAnswer((_) async => null);
      when(() => storage.getValue(backupKey)).thenAnswer((_) async => null);

      final result = await repository.isPinCodeSet();

      expect(
        result,
        isA<Ok<bool, PinCodeFailure>>().having((r) => r.value, 'value', false),
      );
      verifyNever(() => storage.getValue(markerKey));
      verifyNever(() => storage.deleteValue(any()));
      verifyNever(
        () => storage.saveValue(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      );
    });

    test('does not run on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => storage.getValue(key)).thenAnswer((_) async => pin);

      final result = await repository.isPinCodeSet();

      expect(
        result,
        isA<Ok<bool, PinCodeFailure>>().having((r) => r.value, 'value', true),
      );
      verifyNever(() => storage.getValue(markerKey));
      verifyNever(() => storage.deleteValue(any()));
      verifyNever(
        () => storage.saveValue(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      );
    });

    test(
      'a marker read failure is swallowed and does not affect the result',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        when(() => storage.getValue(key)).thenAnswer((_) async => pin);
        when(() => storage.getValue(markerKey)).thenThrow(Exception('boom'));

        final result = await repository.isPinCodeSet();

        expect(
          result,
          isA<Ok<bool, PinCodeFailure>>().having((r) => r.value, 'value', true),
        );
        verifyNever(() => storage.deleteValue(any()));
      },
    );

    test('a delete failure is swallowed, does not affect the result, backs '
        'up the pin first, and does not write the marker', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      stubStoredPin();
      when(() => storage.deleteValue(key)).thenThrow(Exception('boom'));

      final result = await repository.isPinCodeSet();

      expect(
        result,
        isA<Ok<bool, PinCodeFailure>>().having((r) => r.value, 'value', true),
      );
      verify(() => storage.saveValue(key: backupKey, value: pin)).called(1);
      verifyNever(() => storage.saveValue(key: key, value: pin));
      verifyNever(() => storage.saveValue(key: markerKey, value: '1'));
    });

    test('a save failure after delete is retried once and swallowed, does not '
        'affect the result, leaves the backup in place, and does not write '
        'the marker so the next launch retries the heal', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      stubStoredPin();
      when(
        () => storage.saveValue(key: key, value: pin),
      ).thenThrow(Exception('boom'));

      final result = await repository.isPinCodeSet();

      expect(
        result,
        isA<Ok<bool, PinCodeFailure>>().having((r) => r.value, 'value', true),
      );
      verify(() => storage.saveValue(key: backupKey, value: pin)).called(1);
      verify(() => storage.saveValue(key: key, value: pin)).called(2);
      verifyNever(() => storage.saveValue(key: markerKey, value: '1'));
      verifyNever(() => storage.deleteValue(backupKey));
    });
  });
}
