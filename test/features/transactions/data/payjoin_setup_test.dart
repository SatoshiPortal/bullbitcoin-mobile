import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/transactions/public/transactions_facade.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart'
    show InputReservation, InputReservationPort, SyncFailure;

class _Database extends Mock implements SqliteDatabase {}

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
  for (final startRecovery in [false, true]) {
    test(
      'setup registers roles before deferred recovery ($startRecovery)',
      () async {
        final locator = GetIt.asNewInstance();
        _registerSettings(locator);
        addTearDown(locator.reset);
        final database = _Database();
        var openAttempts = 0;
        locator.registerLazySingleton<Secrets>(() {
          openAttempts++;
          throw StateError('storage unavailable');
        });
        PayjoinSetup.setup(
          locator,
          database,
          'unused.sqlite',
          startRecovery: startRecovery,
        );
        expect(openAttempts, 0);
        final payjoin = locator<Payjoin>();
        expect(locator<PayjoinSender>(), same(payjoin.sender));
        expect(locator<PayjoinReceiver>(), same(payjoin.receiver));
        expect(locator<PayjoinSessions>(), same(payjoin.sessions));
        expect(locator<PayjoinPolicyAccess>(), same(payjoin.policy));
        expect(locator<PayjoinDiagnostics>(), same(payjoin.diagnostics));
        await Future<void>.delayed(Duration.zero);
        expect(openAttempts, startRecovery ? 1 : 0);
        verifyZeroInteractions(database);
        await locator<PayjoinLifecycle>().dispose();
        verifyZeroInteractions(database);
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
    PayjoinSetup.setup(
      locator,
      _Database(),
      'unused.sqlite',
      startRecovery: false,
    );

    final result = await locator<InputReservationPort>().reservations();

    expect(result, isA<Err<List<InputReservation>, SyncFailure>>());
    await locator<PayjoinLifecycle>().dispose();
  });
}
