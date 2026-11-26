import 'package:bb_mobile/network_banner.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/setup.dart';

class _Preferences extends Mock implements Preferences {}

class _PreferencesDao extends Mock implements PreferencesDao {}

class _Tor extends Mock implements Tor {}

class _EmbeddedTor extends Mock implements EmbeddedTor {}

void main() {
  for (final production in [Environment.mainnet, Environment.testnet]) {
    for (final startsOnRegtest in [false, true]) {
      final initial = startsOnRegtest ? Environment.regtest : production;
      final target = startsOnRegtest ? production : Environment.regtest;
      testWidgets('$initial to $target keeps the captured RecoverBull family', (
        tester,
      ) async {
        var selected = SettingsEntity(
          environment: initial,
          bitcoinUnit: BitcoinUnit.btc,
          currencyCode: 'USD',
          isSuperuser: true,
          isDevModeEnabled: true,
        );
        final preferences = _Preferences();
        final tor = _Tor();
        final services = GetIt.asNewInstance();
        when(preferences.fetch).thenAnswer((_) async => Ok(selected));
        when(() => tor.embedded).thenReturn(_EmbeddedTor());
        services.registerSingleton<Preferences>(preferences);
        services.registerSingleton<RecoverBullPreferences>(
          PreferencesTesting.fromDao(_PreferencesDao()).recoverBull,
        );
        services.registerSingleton<Tor>(tor);
        addTearDown(services.reset);

        final captured = await SettingsRecoverBullBindings.setup(
          services,
          databasePath: '/tmp/banner-runtime/recoverbull.sqlite',
          regtestHost: 'stack.example',
        );
        expect(
          captured.path.endsWith('recoverbull-regtest.sqlite'),
          startsOnRegtest,
        );
        expect(
          await services<RecoverBullEnvironmentPort>().currentNetwork(),
          isA<Ok<BitcoinNetwork, RecoverBullFailure>>().having(
            (result) => result.value.name,
            'initial network',
            initial.name,
          ),
        );

        Future<void> pumpSelected() => tester.pumpWidget(
          AppliedNetworkBuilder(
            selected: selected.environment.networkEnv,
            builder: (context, applied) => MaterialApp(
              debugShowCheckedModeBanner: false,
              builder: (context, child) => networkBanner(
                context: context,
                network: applied,
                beta: true,
                child: child ?? const SizedBox.shrink(),
              ),
              home: const Scaffold(),
            ),
          ),
        );
        await pumpSelected();
        selected = selected.copyWith(environment: target);
        await pumpSelected();

        expect(
          await services<RecoverBullEnvironmentPort>().currentNetwork(),
          isA<Err<BitcoinNetwork, RecoverBullFailure>>().having(
            (result) => result.failure,
            'runtime rejects the pending network',
            isA<VaultContextChangedFailure>(),
          ),
        );
        expect(
          tester.widget<Banner>(find.byType(Banner)).message,
          initial == Environment.mainnet ? 'BETA' : initial.name.toUpperCase(),
        );
      });
    }
  }
}
