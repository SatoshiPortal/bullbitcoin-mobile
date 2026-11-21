import 'package:preferences/preferences.dart' show Environment, SettingsEntity;
import 'package:bb_mobile/features/settings/ui/widgets/amount_input_mode_setting.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/settings/ui/screens/app_settings/app_settings_screen.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements SettingsCubit {}

class _Prices extends Mock implements BitcoinPriceBloc {}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });

  testWidgets('a failed write restores the persisted segment', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final cubit = _Settings();
      when(() => cubit.state).thenReturn(
        const SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
          ),
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.setStartAmountsInFiat(true))
          .thenAnswer((_) async => const Err(SettingsStorageFailure()));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: const [
            bullUiLocalizationsDelegate,
            ...appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<SettingsCubit>.value(
            value: cubit,
            child: const Scaffold(body: AmountInputModeSetting()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CAD'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Bitcoin')),
        matchesSemantics(
          label: 'Bitcoin',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          isSelected: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      verify(() => cubit.setStartAmountsInFiat(true)).called(1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('amount input setting is named and selected in ${theme.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final cubit = _Settings();
        when(() => cubit.state).thenReturn(
          const SettingsState(
            storedSettings: SettingsEntity(
              environment: Environment.mainnet,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'CAD',
              hideAmounts: false,
            ),
          ),
        );
        when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
        when(() => cubit.setStartAmountsInFiat(true))
            .thenAnswer((_) async => const Ok(null));
        final prices = _Prices();
        when(() => prices.state).thenReturn(
          const BitcoinPriceState(availableCurrencies: ['CAD', 'USD', 'EUR']),
        );
        when(() => prices.stream).thenAnswer((_) => const Stream.empty());
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            theme: AppTheme.themeData(theme),
            localizationsDelegates: const [
              bullUiLocalizationsDelegate,
              ...appLocalizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<SettingsCubit>.value(value: cubit),
                BlocProvider<BitcoinPriceBloc>.value(value: prices),
              ],
              child: RepaintBoundary(
                key: boundary,
                child: const AppSettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Enter amounts in'), findsOneWidget);
        final selected = find.descendant(
          of: find.byType(BullSegmented),
          matching: find.text('Bitcoin'),
        );
        expect(
          tester.getSemantics(selected),
          matchesSemantics(
            label: 'Bitcoin',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
            hasFocusAction: true,
            isFocusable: true,
            isSelected: true,
            hasSelectedState: true,
            isInMutuallyExclusiveGroup: true,
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        // A picker row reads its title once, followed by its value.
        expect(
          find.bySemanticsLabel(RegExp('Currency\nCurrency')),
          findsNothing,
        );
        await expectLater(
          find.byKey(boundary),
          matchesGoldenFile('goldens/amount-input-settings-${theme.name}.png'),
        );
        final cad = find.descendant(
          of: find.byType(BullSegmented),
          matching: find.text('CAD'),
        );
        await tester.tap(cad);
        await tester.pumpAndSettle();
        verify(() => cubit.setStartAmountsInFiat(true)).called(1);
      } finally {
        semantics.dispose();
      }
    });
  }
}
