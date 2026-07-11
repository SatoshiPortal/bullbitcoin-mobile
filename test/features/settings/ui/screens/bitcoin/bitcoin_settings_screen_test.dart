import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/bitcoin_settings_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

SettingsState _settingsState({
  bool isSuperuser = true,
  bool isDevModeEnabled = true,
  bool isSpWalletSetup = false,
}) => SettingsState(
  storedSettings: SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    isSuperuser: isSuperuser,
    isDevModeEnabled: isDevModeEnabled,
  ),
  isSpWalletSetup: isSpWalletSetup,
);

Widget _buildPage({required SettingsCubit settingsCubit}) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SettingsCubit>.value(
    value: settingsCubit,
    child: const BitcoinSettingsScreen(),
  ),
);

void main() {
  late _MockSettingsCubit settingsCubit;

  setUp(() {
    settingsCubit = _MockSettingsCubit();
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => settingsCubit.checkSpWalletSetup()).thenAnswer((_) async {});
  });

  // Pumps the screen with the given gate flags + setup state. Both SP entries
  // are gated behind superuser AND dev mode; only one number differs per case.
  Future<void> pumpScreen(
    WidgetTester tester, {
    required bool isSuperuser,
    required bool isDevModeEnabled,
    required bool isSpWalletSetup,
  }) async {
    when(() => settingsCubit.state).thenReturn(
      _settingsState(
        isSuperuser: isSuperuser,
        isDevModeEnabled: isDevModeEnabled,
        isSpWalletSetup: isSpWalletSetup,
      ),
    );
    await tester.pumpWidget(_buildPage(settingsCubit: settingsCubit));
  }

  group('superuser + dev mode both on', () {
    testWidgets('not setup shows Create SP Wallet only', (tester) async {
      await pumpScreen(
        tester,
        isSuperuser: true,
        isDevModeEnabled: true,
        isSpWalletSetup: false,
      );

      expect(find.text('Create SP Wallet'), findsOneWidget);
      expect(find.text('SP Wallet Settings'), findsNothing);
    });

    testWidgets('setup shows SP Wallet Settings only', (tester) async {
      await pumpScreen(
        tester,
        isSuperuser: true,
        isDevModeEnabled: true,
        isSpWalletSetup: true,
      );

      expect(find.text('SP Wallet Settings'), findsOneWidget);
      expect(find.text('Create SP Wallet'), findsNothing);
    });

    testWidgets('refreshes the SP setup flag on entry', (tester) async {
      await pumpScreen(
        tester,
        isSuperuser: true,
        isDevModeEnabled: true,
        isSpWalletSetup: false,
      );

      verify(() => settingsCubit.checkSpWalletSetup()).called(1);
    });
  });

  group('gate off hides BOTH SP entries regardless of setup', () {
    // Each false flag alone must hide both the create and settings entries, for
    // both setup states, so a stale isSpWalletSetup can never leak an SP entry.
    for (final isSpWalletSetup in [false, true]) {
      testWidgets('superuser off (setup=$isSpWalletSetup)', (tester) async {
        await pumpScreen(
          tester,
          isSuperuser: false,
          isDevModeEnabled: true,
          isSpWalletSetup: isSpWalletSetup,
        );

        expect(find.text('Create SP Wallet'), findsNothing);
        expect(find.text('SP Wallet Settings'), findsNothing);
      });

      testWidgets('dev mode off (setup=$isSpWalletSetup)', (tester) async {
        await pumpScreen(
          tester,
          isSuperuser: true,
          isDevModeEnabled: false,
          isSpWalletSetup: isSpWalletSetup,
        );

        expect(find.text('Create SP Wallet'), findsNothing);
        expect(find.text('SP Wallet Settings'), findsNothing);
      });
    }
  });
}
