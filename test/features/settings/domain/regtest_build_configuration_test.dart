import 'package:bull_ui/app_theme.dart';
import 'package:preferences/preferences.dart';
import 'package:settings/testing.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart' show BullPickerChip;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:electrum/setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements SettingsCubit {}

void main() {
  testWidgets('regtest network choice follows the configured stack', (
    tester,
  ) async {
    final settings = _Settings();
    when(() => settings.state).thenReturn(
      const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
          isSuperuser: true,
          isDevModeEnabled: true,
        ),
      ),
    );
    when(() => settings.stream)
        .thenAnswer((_) => const Stream<SettingsState>.empty());
    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: settings,
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TestnetModeSwitch()),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final chip = tester.widget<BullPickerChip<Environment>>(
      find.byType(BullPickerChip<Environment>),
    );
    expect(
      chip.items.any((item) => item.value == Environment.regtest),
      RegtestHostProfile.isConfigured,
    );
    expect(chip.items.any((item) => item.value == Environment.mainnet), isTrue);
    expect(chip.items.any((item) => item.value == Environment.testnet), isTrue);
  });

  test('an empty host selects no local Electrum stack', () {
    expect(() => RegtestElectrumProfile(host: ''), throwsFormatException);
  });

  for (final host in [
    ' localhost',
    'local host',
    'http://localhost',
    'localhost:9001',
    'user@localhost',
    'localhost/path',
    'localhost?query',
  ]) {
    test(
      'invalid regtest host refuses shared and Electrum profiles: $host',
      () {
        expect(
          () => RegtestHostProfile.forNetwork(NetworkEnv.regtest, host: host),
          throwsArgumentError,
        );
        expect(() => RegtestElectrumProfile(host: host), throwsFormatException);
      },
    );
  }

  test('regtest services follow the build-selected stack', () {
    const host = String.fromEnvironment('BULL_REGTEST_HOST');
    if (host.isEmpty) {
      final profile = RegtestHostProfile.forNetwork(NetworkEnv.regtest);
      final endpoints = (profile! as HostedRegtestStack).endpoints;
      expect(
        RegtestElectrumProfile.fromBuildEnvironment().bitcoin,
        endpoints.electrumBitcoin.toString(),
      );
    } else {
      final profile = RegtestHostProfile.forNetwork(NetworkEnv.regtest);
      expect(
        (profile! as LocalRegtestHost).host,
        Uri.parse('http://$host').host,
      );
      expect(
        RegtestElectrumProfile.fromBuildEnvironment().bitcoin,
        startsWith('tcp://'),
      );
    }
    expect(RegtestHostProfile.forNetwork(NetworkEnv.mainnet), isNull);
    expect(RegtestHostProfile.forNetwork(NetworkEnv.testnet), isNull);
    final local = RegtestHostProfile.forNetwork(
      NetworkEnv.regtest,
      host: 'stack.example',
      hosted: const RegtestHostedDefines(
        electrumBitcoin: '',
        electrumLiquid: '',
        esploraBitcoin: '',
        esploraLiquid: '',
        boltzApi: '',
        boltzWebSocket: '',
        recoverBull: '',
      ),
    );
    expect((local! as LocalRegtestHost).host, 'stack.example');
  });

  test('Electrum follows the selected regtest stack', () {
    final local = RegtestElectrumProfile(host: 'stack.example');
    expect(local.endpoint(isLiquid: false), 'tcp://stack.example:50000');
    expect(local.endpoint(isLiquid: true), 'tcp://stack.example:50001');
    expect(
      RegtestElectrumProfile(host: '[::1]').endpoint(isLiquid: false),
      'tcp://[::1]:50000',
    );
    final hosted = RegtestElectrumProfile.of(
      RegtestHostProfile.forNetwork(
        NetworkEnv.regtest,
        host: '',
        hosted: const RegtestHostedDefines(
          electrumBitcoin: 'ssl://electrum.example:443',
          electrumLiquid: 'ssl://electrum.example:8443',
          esploraBitcoin: 'https://esplora.example',
          esploraLiquid: 'https://liquid.example',
          boltzApi: 'https://boltz.example/v2',
          boltzWebSocket: 'wss://boltz.example/v2/ws',
          recoverBull: 'http://keyserver.onion',
        ),
      )!,
    );
    expect(hosted.endpoint(isLiquid: false), 'ssl://electrum.example:443');
    expect(hosted.endpoint(isLiquid: true), 'ssl://electrum.example:8443');
  });
}
