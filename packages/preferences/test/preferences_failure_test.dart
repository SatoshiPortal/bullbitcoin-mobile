import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';

class _Dao extends Mock implements PreferencesDao {}

class _LegacyDao extends Mock implements LegacyPreferencesDao {}

const _row = OwnerSettingsRow(
  id: 1,
  environment: 'mainnet',
  bitcoinUnit: 'sats',
  startAmountsInFiat: false,
  language: 'unitedStatesEnglish',
  currency: 'USD',
  hideAmounts: false,
  isSuperuser: false,
  isDevModeEnabled: false,
  useTorProxy: false,
  torProxyPort: 9050,
  torTransportMode: 'automatic',
  themeMode: 'system',
  isErrorReportingEnabled: false,
  screenCaptureProtectionEnabled: true,
);

void main() {
  late _Dao dao;
  late _LegacyDao legacy;
  late Preferences preferences;
  setUp(() {
    dao = _Dao();
    legacy = _LegacyDao();
    preferences = PreferencesTesting.fromDao(dao, legacy: legacy);
    addTearDown(preferences.close);
  });

  test(
    'all reads return sanitized failures without a fallback value',
    () async {
      const raw = 'private persistence detail';
      when(dao.fetch).thenThrow(Exception(raw));
      final results = await Future.wait([
        preferences.fetch(),
        preferences.readLanguage(),
        preferences.readCurrency(),
        preferences.readActiveEnvironment(),
        preferences.readConnectionPreferences(),
        preferences.readDeveloperEnvironment(),
        preferences.readTorProxyPreferences(),
        preferences.readExchangeWebPreferences(),
      ]);
      for (final result in results) {
        result.fold(
          (_) => fail('A failed read must not fabricate a preference'),
          (failure) {
            expect(failure, isA<PreferencesReadFailure>());
            expect(failure.logMessage, isNot(contains(raw)));
          },
        );
      }
    },
  );

  test(
    'missing and malformed persisted settings have distinct failures',
    () async {
      when(dao.fetch).thenThrow(const PreferencesMissingRowException());
      expect(
        await preferences.fetch(),
        isA<Err<SettingsEntity, PreferencesFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<PreferencesMissingFailure>(),
        ),
      );
      when(dao.fetch).thenThrow(const FormatException('invalid stored value'));
      expect(
        await preferences.fetch(),
        isA<Err<SettingsEntity, PreferencesFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<PreferencesInvalidFailure>(),
        ),
      );
    },
  );

  test('programmer errors escape read and write boundaries', () async {
    when(dao.fetch).thenThrow(StateError('programmer error'));
    when(() => dao.setCurrency('CAD'))
        .thenThrow(StateError('programmer error'));
    await expectLater(preferences.fetch(), throwsStateError);
    await expectLater(preferences.setCurrency('CAD'), throwsStateError);
  });

  test('display observation reports a read failure and continues', () async {
    final source = StreamController<OwnerSettingsRow?>();
    when(dao.watchSettings).thenAnswer((_) => source.stream);
    final observed = expectLater(
      preferences.watchDisplayPreferences(),
      emitsInOrder([
        isA<Ok<AmountDisplayPreferences, PreferencesFailure>>().having(
          (result) => result.value.hideAmounts,
          'hideAmounts',
          false,
        ),
        isA<Err<AmountDisplayPreferences, PreferencesFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<PreferencesReadFailure>(),
        ),
        isA<Ok<AmountDisplayPreferences, PreferencesFailure>>().having(
          (result) => result.value.hideAmounts,
          'hideAmounts',
          true,
        ),
        emitsDone,
      ]),
    );
    source.add(_row);
    source.addError(Exception('unreadable database'));
    source.add(_row.copyWith(hideAmounts: true));
    await source.close();
    await observed;
  });

  test('display observation does not swallow programmer errors', () async {
    when(dao.watchSettings)
        .thenAnswer((_) => Stream.error(StateError('programmer error')));
    await expectLater(
      preferences.watchDisplayPreferences(),
      emitsError(isA<StateError>()),
    );
  });

  test('RecoverBull permission reads return a Preferences failure', () async {
    when(() => dao.readRecoverBullPermission(regtest: false))
        .thenThrow(Exception('permission read failed'));
    expect(
      await preferences.recoverBull.read(),
      isA<Err<bool?, PreferencesFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<PreferencesReadFailure>(),
      ),
    );
  });
}
