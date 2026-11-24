import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:receive/receive.dart';
import 'package:receive/testing.dart';
import 'package:settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockSettingsFacade extends Mock implements Settings {}

class _MockPolicy extends Mock implements PayjoinPolicyAccess {}

const _rawReason = 'Bad state: No element (settings stream closed)';

void main() {
  group('GetReceivePayjoinPolicyUsecase', () {
    test('returns the policy on success', () async {
      final settings = _MockPolicy();
      when(() => settings.watch()).thenAnswer(
        (_) => Stream.value(
          Ok(PayjoinPolicy.defaults().copyWith(receiveEnabled: true)),
        ),
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
      final settings = _MockPolicy();
      when(() => settings.watch()).thenAnswer((_) => const Stream.empty());

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

    test('an errored stream becomes a sanitized failure with no raw reason in '
        'logMessage only', () async {
      final settings = _MockPolicy();
      when(() => settings.watch())
          .thenAnswer((_) => Stream.error(StateError(_rawReason)));

      final result = await GetReceivePayjoinPolicyUsecase(settings).execute();

      switch (result) {
        case Ok():
          fail('an errored policy stream must not be reported as a policy');
        case Err(:final failure):
          expect(failure, isA<ReceivePayjoinPolicyUnavailableFailure>());
          expect(failure.logMessage, isNot(contains('settings stream closed')));
      }
    });
  });

  group('SetReceivePayjoinEnabledUsecase', () {
    test('lifts a SettingsFailure into this feature\'s family, so the receive '
        'UI never translates a foreign failure type', () async {
      final settings = _MockSettingsFacade();
      when(
        () => settings.setPayjoinReceiveEnabled(
          any(),
          requestConsent: any(named: 'requestConsent'),
        ),
      ).thenAnswer(
        (_) async => const Err<bool, SettingsFailure>(
          SettingsStorageFailure('shared_prefs write failed: EACCES'),
        ),
      );

      final result = await SetReceivePayjoinEnabledUsecase(
        settings.setPayjoinReceiveEnabled,
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
        () => settings.setPayjoinReceiveEnabled(
          any(),
          requestConsent: any(named: 'requestConsent'),
        ),
      ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(true));

      final result = await SetReceivePayjoinEnabledUsecase(
        settings.setPayjoinReceiveEnabled,
      ).execute(true, requestConsent: () async => true);

      expect((result as Ok<bool, ReceiveFailure>).value, isTrue);
    });
  });
}
