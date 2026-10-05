import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/app_settings/app_settings_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

SettingsState _settingsState({bool revokeSpFailed = false}) => SettingsState(
  storedSettings: const SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    isSuperuser: true,
    isDevModeEnabled: true,
  ),
  revokeSpFailed: revokeSpFailed,
);

Widget _buildPage({required SettingsCubit settingsCubit}) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // AppLanguagePicker sizes itself off Device.screen, which main() seeds at
  // startup; do the same here rather than stubbing the picker out.
  home: Builder(
    builder: (context) {
      Device.init(context);
      return BlocProvider<SettingsCubit>.value(
        value: settingsCubit,
        child: const AppSettingsScreen(),
      );
    },
  ),
);

void main() {
  late _MockSettingsCubit settingsCubit;

  // The revoke leaves the wallet unloadable but still on disk, and only the
  // user can retry it, so the failure has to reach the screen.
  const failureMessage =
      'Could not fully delete the Silent Payments wallet. It is disabled and '
      'cannot be reloaded. Turn developer mode off again to retry.';

  setUp(() {
    settingsCubit = _MockSettingsCubit();
    when(() => settingsCubit.state).thenReturn(_settingsState());
  });

  // Tall enough that the settings list lays out without overflowing.
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_buildPage(settingsCubit: settingsCubit));
  }

  testWidgets('a failed silent payments revoke is surfaced', (tester) async {
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => Stream.value(_settingsState(revokeSpFailed: true)));

    await pumpScreen(tester);
    when(
      () => settingsCubit.state,
    ).thenReturn(_settingsState(revokeSpFailed: true));
    await tester.pump();
    await tester.pump();

    expect(find.text(failureMessage), findsOneWidget);

    // Drain the snackbar's own display timer so it does not outlive the test.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a clean dev mode toggle says nothing', (tester) async {
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => Stream.value(_settingsState()));

    await pumpScreen(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text(failureMessage), findsNothing);
  });
}
