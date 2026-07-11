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

  group('legacy keychain accessibility heal', () {
    void stubStoredPin({String? markerValue}) {
      when(() => storage.getValue(key)).thenAnswer((_) async => pin);
      when(
        () => storage.getValue(markerKey),
      ).thenAnswer((_) async => markerValue);
      when(() => storage.deleteValue(key)).thenAnswer((_) async {});
      when(
        () => storage.saveValue(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
    }

    test('on iOS with no healed marker, a successful read deletes and re-saves '
        'the same pin so the item is re-added under the current accessibility '
        'class, then writes the marker', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      stubStoredPin();

      final result = await repository.isPinCodeSet();

      expect(
        result,
        isA<Ok<bool, PinCodeFailure>>().having((r) => r.value, 'value', true),
      );
      verifyInOrder([
        () => storage.getValue(markerKey),
        () => storage.deleteValue(key),
        () => storage.saveValue(key: key, value: pin),
        () => storage.saveValue(key: markerKey, value: '1'),
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

    test('a delete failure is swallowed, does not affect the result, and does '
        'not write the marker', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      stubStoredPin();
      when(() => storage.deleteValue(key)).thenThrow(Exception('boom'));

      final result = await repository.isPinCodeSet();

      expect(
        result,
        isA<Ok<bool, PinCodeFailure>>().having((r) => r.value, 'value', true),
      );
      verifyNever(
        () => storage.saveValue(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      );
    });

    test('a save failure after delete is retried once and swallowed, does not '
        'affect the result, and does not write the marker so the next launch '
        'retries the heal', () async {
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
      verify(() => storage.saveValue(key: key, value: pin)).called(2);
      verifyNever(() => storage.saveValue(key: markerKey, value: '1'));
    });
  });
}
