import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/testnet_mode_switch.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart' show BullPickerChip;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:electrum/electrum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements SettingsCubit {}

void main() {
  testWidgets('regtest network choice requires the explicit build host', (
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
    const host = String.fromEnvironment('BULL_REGTEST_HOST');
    expect(
      chip.items.any((item) => item.value == Environment.regtest),
      host.isNotEmpty,
    );
    expect(chip.items.any((item) => item.value == Environment.mainnet), isTrue);
    expect(chip.items.any((item) => item.value == Environment.testnet), isTrue);
  });

  for (final host in [
    '',
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

  test('regtest services require an explicit build host', () {
    const host = String.fromEnvironment('BULL_REGTEST_HOST');
    if (host.isEmpty) {
      expect(
        () => RegtestHostProfile.forNetwork(NetworkEnv.regtest),
        throwsArgumentError,
      );
      expect(
        RegtestElectrumProfile.fromBuildEnvironment,
        throwsFormatException,
      );
    } else {
      expect(
        RegtestHostProfile.forNetwork(NetworkEnv.regtest)?.host,
        Uri.parse('http://$host').host,
      );
      expect(RegtestElectrumProfile.fromBuildEnvironment().host, host);
    }
    expect(RegtestHostProfile.forNetwork(NetworkEnv.mainnet), isNull);
    expect(RegtestHostProfile.forNetwork(NetworkEnv.testnet), isNull);
    expect(
      RegtestHostProfile.forNetwork(
        NetworkEnv.regtest,
        host: 'stack.example',
      )?.host,
      'stack.example',
    );
  });
}
