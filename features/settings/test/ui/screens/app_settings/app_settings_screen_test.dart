import 'package:bitcoin_price/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_ui/bull_ui.dart' show BullPickerChip;
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bull_ui/app_theme.dart';
import 'package:settings/testing.dart';
import 'package:material_ui/material_ui.dart';
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
  localizationsDelegates: settingsTestLocalizationsDelegates,
  supportedLocales: SettingsLocalizations.supportedLocales,
  // The translation warning sizes itself off Device.screen, which main() seeds at
  // startup; do the same here rather than stubbing the picker out.
  home: Builder(
    builder: (context) {
      Device.init(context);

      return MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BitcoinPriceFixture.prices(availableCurrencies: const ['USD', 'CAD']),
        ],
        child: const AppSettingsScreen(),
      );
    },
  ),
);

void main() {
  late _MockSettingsCubit settingsCubit;

  setUpAll(() => registerFallbackValue(AppThemeMode.system));

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
    when(() => settingsCubit.stream)
        .thenAnswer((_) => Stream.value(_settingsState(revokeSpFailed: true)));

    await pumpScreen(tester);
    when(() => settingsCubit.state)
        .thenReturn(_settingsState(revokeSpFailed: true));
    await tester.pump();
    await tester.pump();

    expect(find.text(failureMessage), findsOneWidget);

    // Drain the snackbar's own display timer so it does not outlive the test.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('the dark mode switch stores an explicit theme', (tester) async {
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => settingsCubit.changeThemeMode(any())).thenAnswer((_) async {});

    await pumpScreen(tester);
    await tester.pump();

    expect(find.text('Dark Mode'), findsOneWidget);
    final darkMode = find.ancestor(
      of: find.text('Dark Mode'),
      matching: find.byType(ListTile),
    );
    final toggle = find.descendant(of: darkMode, matching: find.byType(Switch));
    // The page runs the light theme, so the switch reads off.
    expect(tester.widget<Switch>(toggle).value, isFalse);

    await tester.tap(toggle);
    verify(() => settingsCubit.changeThemeMode(AppThemeMode.dark)).called(1);
  });

  testWidgets('the payment animations switch is on by default and toggles', (
    tester,
  ) async {
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => settingsCubit.toggleShowPaymentAnimations(any()))
        .thenAnswer((_) async {});

    await pumpScreen(tester);
    await tester.pump();

    expect(find.text('Payment animations'), findsOneWidget);
    expect(
      find.text('When off, payments open their details directly.'),
      findsOneWidget,
    );
    final tile = find.ancestor(
      of: find.text('Payment animations'),
      matching: find.byType(ListTile),
    );
    final toggle = find.descendant(of: tile, matching: find.byType(Switch));
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    verify(() => settingsCubit.toggleShowPaymentAnimations(false)).called(1);
  });

  testWidgets('a clean dev mode toggle says nothing', (tester) async {
    when(() => settingsCubit.stream)
        .thenAnswer((_) => Stream.value(_settingsState()));

    await pumpScreen(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text(failureMessage), findsNothing);
  });

  // The fiat currency is picked in place, like the language; there is no
  // separate currency screen any more.
  testWidgets('the default currency is picked inline', (tester) async {
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    await pumpScreen(tester);

    final chip = tester.widget<BullPickerChip<String>>(
      find.byType(BullPickerChip<String>),
    );
    expect(chip.value, 'USD');
  });
}
