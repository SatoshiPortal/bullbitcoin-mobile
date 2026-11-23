import 'package:preferences/testing.dart';

import 'dart:async';

import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:bull_tor/tor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../../../support/preferences_database.dart';

void main() {
  final writes =
      <String, Future<Result<void, PreferencesFailure>> Function(Preferences)>{
        'environment': (p) => p.setEnvironment(Environment.testnet),
        'currency': (p) => p.setCurrency('CAD'),
        'unit': (p) => p.setBitcoinUnit(BitcoinUnit.btc),
        'language': (p) => p.setLanguage(Language.franceFrench),
        'amount visibility': (p) => p.setHideAmounts(true),
        'amount input': (p) => p.setStartAmountsInFiat(true),
        'superuser': (p) => p.setIsSuperuser(false),
        'developer mode': (p) => p.setIsDevMode(false),
        'proxy': (p) => p.setTorProxy(enabled: true, port: 9050),
        'transport': (p) => p.setTorTransportMode(TorTransportMode.automatic),
        'successful transport': (p) =>
            p.setLastSuccessfulTorTransport(TorTransport.direct),
        'theme': (p) => p.setThemeMode(AppThemeMode.dark),
        'reporting': (p) => p.setErrorReportingEnabled(true),
        'screen protection': (p) => p.setScreenCaptureProtectionEnabled(true),
        'exchange web authorization': (p) => p.setExchangeTestnetBasicAuth(),
      };
  for (final write in writes.entries) {
    test(
      '${write.key} rejects a missing row without announcing a change',
      () async {
        final legacy = SqliteDatabase(NativeDatabase.memory());
        final database = await createPreferencesDatabase();
        final preferences = PreferencesTesting.fromDatabases(
          owner: database,
          legacy: legacy,
        );
        final notifications = <Object>[];
        final subscriptions = <StreamSubscription<Object>>[
          preferences.currencyChangeStream.listen(notifications.add),
          preferences.environmentChangeStream.listen(notifications.add),
        ];
        addTearDown(() async {
          for (final subscription in subscriptions) {
            await subscription.cancel();
          }
          await preferences.close();
          await database.close();
          await legacy.close();
        });
        expect(await database.delete(database.ownerSettings).go(), 1);
        expect(await legacy.delete(legacy.settings).go(), 1);
        final result = await write.value(preferences);
        expect(
          result,
          isA<Err<void, PreferencesFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<PreferencesMissingFailure>(),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(notifications, isEmpty);
        expect(await database.select(database.ownerSettings).get(), isEmpty);
        expect(await legacy.select(legacy.settings).get(), isEmpty);
      },
    );
  }
}
