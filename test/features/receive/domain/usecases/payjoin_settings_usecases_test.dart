import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/receive/domain/usecases/fetch_receive_note_suggestions_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_payjoin_policy_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/set_receive_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockSettingsFacade extends Mock implements SettingsFacade {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

const _rawReason = 'Bad state: No element (settings stream closed)';

void main() {
  group('GetReceivePayjoinPolicyUsecase', () {
    test('returns the policy on success', () async {
      final settings = _MockSettingsFacade();
      when(() => settings.watchPayjoinPolicy()).thenAnswer(
        (_) => Stream.value((enabled: true, minimumAmountSat: 10000)),
      );

      final result = await GetReceivePayjoinPolicyUsecase(settings).execute();

      expect(result, isA<Ok<ReceivePayjoinPolicy, ReceiveFailure>>());
      expect(
        (result as Ok<ReceivePayjoinPolicy, ReceiveFailure>).value.enabled,
        isTrue,
      );
    });

    test('an empty stream throws on .first — that must become a failure, '
        'never escape into the bloc', () async {
      final settings = _MockSettingsFacade();
      when(
        () => settings.watchPayjoinPolicy(),
      ).thenAnswer((_) => const Stream.empty());

      final result = await GetReceivePayjoinPolicyUsecase(settings).execute();

      switch (result) {
        case Ok():
          fail('an empty policy stream must not be reported as a policy');
        case Err(:final failure):
          // Distinct from ReceivePayjoinSettingFailure on purpose: that one is
          // rendered as a snackbar by the toggle, and a failed background
          // policy read must not interrupt the user.
          expect(failure, isA<ReceivePayjoinPolicyUnavailableFailure>());
          expect(failure, isNot(isA<ReceivePayjoinSettingFailure>()));
      }
    });

    test('an errored stream becomes a failure carrying the raw reason in '
        'logMessage only', () async {
      final settings = _MockSettingsFacade();
      when(
        () => settings.watchPayjoinPolicy(),
      ).thenAnswer((_) => Stream.error(StateError(_rawReason)));

      final result = await GetReceivePayjoinPolicyUsecase(settings).execute();

      switch (result) {
        case Ok():
          fail('an errored policy stream must not be reported as a policy');
        case Err(:final failure):
          expect(failure, isA<ReceivePayjoinPolicyUnavailableFailure>());
          expect(failure.logMessage, contains('settings stream closed'));
      }
    });
  });

  group('SetReceivePayjoinEnabledUsecase', () {
    test('lifts a SettingsFailure into this feature\'s family, so the receive '
        'UI never translates a foreign failure type', () async {
      final settings = _MockSettingsFacade();
      when(
        () => settings.setPayjoinEnabled(
          any(),
          requestConsent: any(named: 'requestConsent'),
        ),
      ).thenAnswer(
        (_) async => const Err<bool, SettingsFailure>(
          SettingsStorageFailure('shared_prefs write failed: EACCES'),
        ),
      );

      final result = await SetReceivePayjoinEnabledUsecase(
        settingsFacade: settings,
      ).execute(true, requestConsent: () async => true);

      switch (result) {
        case Ok():
          fail('a failed persist must not be reported as saved');
        case Err(:final failure):
          expect(failure, isA<ReceivePayjoinSettingFailure>());
          expect(failure.logMessage, contains('EACCES'));
      }
    });

    test('forwards the persisted value on success', () async {
      final settings = _MockSettingsFacade();
      when(
        () => settings.setPayjoinEnabled(
          any(),
          requestConsent: any(named: 'requestConsent'),
        ),
      ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(true));

      final result = await SetReceivePayjoinEnabledUsecase(
        settingsFacade: settings,
      ).execute(true, requestConsent: () async => true);

      expect((result as Ok<bool, ReceiveFailure>).value, isTrue);
    });
  });

  group('FetchReceiveNoteSuggestionsUsecase', () {
    test('converts a throw into a sanitized failure', () async {
      final labels = _MockLabelsFacade();
      when(
        () => labels.fetchDistinctLabels(type: any(named: 'type')),
      ).thenThrow(Exception('drift: no such table labels'));

      final result = await FetchReceiveNoteSuggestionsUsecase(labels).execute();

      switch (result) {
        case Ok():
          fail('a throw must not be reported as suggestions');
        case Err(:final failure):
          expect(failure, isA<ReceiveUnexpectedFailure>());
          expect(failure.logMessage, contains('no such table'));
      }
    });

    test('scopes suggestions to address labels — a transaction label is '
        'private and must never become a BIP21 message=', () async {
      final labels = _MockLabelsFacade();
      when(
        () => labels.fetchDistinctLabels(type: any(named: 'type')),
      ).thenAnswer((_) async => {'lunch'});

      final result = await FetchReceiveNoteSuggestionsUsecase(labels).execute();
      expect(result, isA<Ok<Set<String>, ReceiveFailure>>());

      verify(
        () => labels.fetchDistinctLabels(type: LabelType.address),
      ).called(1);
    });
  });
}
