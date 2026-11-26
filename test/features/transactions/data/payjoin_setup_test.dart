import 'package:preferences/preferences.dart';
import 'package:transactions/setup.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart'
    show InputReservation, InputReservationPort, SyncFailure;

class _Settings extends Mock implements Preferences {}

void _registerSettings(GetIt locator) {
  final settings = _Settings();
  when(settings.fetch).thenAnswer(
    (_) async => Ok(
      const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    ),
  );
  locator.registerSingleton<Preferences>(settings);
}

void main() {
  if (RegtestHostProfile.isConfigured) {
    test('first open captures the selected regtest runtime family', () async {
      final locator = GetIt.asNewInstance();
      final settings = _Settings();
      var environment = Environment.regtest;
      when(settings.fetch).thenAnswer(
        (_) async => Ok(
          SettingsEntity(
            environment: environment,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
          ),
        ),
      );
      locator.registerSingleton<Preferences>(settings);
      locator.registerLazySingleton<RuntimeAdmission>(
        () => throw StateError('storage unavailable'),
      );
      addTearDown(locator.reset);
      mountPayjoin(locator, startRecovery: false);
      final lifecycle = locator<PayjoinLifecycle>();
      expect(await lifecycle.resume(), isA<Err<void, PayjoinFailure>>());
      environment = Environment.mainnet;
      final result = await lifecycle.resume();
      expect(
        result,
        isA<Err<void, PayjoinFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<PayjoinUnavailableFailure>().having(
            (failure) => failure.logMessage,
            'reason',
            'Payjoin runtime family changed',
          ),
        ),
      );
      await lifecycle.dispose();
    });
  }
  for (final startRecovery in [false, true]) {
    test(
      'setup registers roles before deferred recovery ($startRecovery)',
      () async {
        final locator = GetIt.asNewInstance();
        _registerSettings(locator);
        addTearDown(locator.reset);
        var openAttempts = 0;
        locator.registerLazySingleton<RuntimeAdmission>(() {
          openAttempts++;
          throw StateError('storage unavailable');
        });
        mountPayjoin(locator, startRecovery: startRecovery);
        expect(openAttempts, 0);
        final payjoin = locator<Payjoin>();
        expect(locator<PayjoinSender>(), same(payjoin.sender));
        expect(locator<PayjoinReceiver>(), same(payjoin.receiver));
        expect(locator<PayjoinSessions>(), same(payjoin.sessions));
        expect(locator<PayjoinPolicyAccess>(), same(payjoin.policy));
        expect(locator<PayjoinDiagnostics>(), same(payjoin.diagnostics));
        await Future<void>.delayed(Duration.zero);
        expect(openAttempts, startRecovery ? 1 : 0);
        await locator<PayjoinLifecycle>().dispose();
      },
    );
  }

  test('sync reads no reservation while Payjoin storage cannot open', () async {
    final locator = GetIt.asNewInstance();
    _registerSettings(locator);
    addTearDown(locator.reset);
    locator.registerLazySingleton<Secrets>(
      () => throw StateError('storage unavailable'),
    );
    mountPayjoin(locator, startRecovery: false);

    final result = await locator<InputReservationPort>().reservations();

    expect(result, isA<Err<List<InputReservation>, SyncFailure>>());
    await locator<PayjoinLifecycle>().dispose();
  });
}
