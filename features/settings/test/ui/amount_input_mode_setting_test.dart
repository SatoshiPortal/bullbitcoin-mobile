import 'dart:io';

import 'package:preferences/preferences.dart' show Environment, SettingsEntity;
import 'package:settings/testing.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements SettingsCubit {}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('Golos Text')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('../../assets/fonts/GolosText.ttf').readAsBytes(),
            ),
          ),
        ))
        .load();
  });

  testWidgets('a failed write keeps the persisted choice', (tester) async {
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
          ...settingsTestLocalizationsDelegates,
        ],
        supportedLocales: SettingsLocalizations.supportedLocales,
        home: BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: const Scaffold(body: AmountInputModeSetting()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BullPickerChip<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CAD').last);
    await tester.pumpAndSettle();
    verify(() => cubit.setStartAmountsInFiat(true)).called(1);
    expect(
      find.descendant(
        of: find.byType(BullPickerChip<bool>),
        matching: find.text('Bitcoin'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('amount input setting is a named picker in ${theme.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 430);
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

        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            theme: AppTheme.themeData(theme),
            localizationsDelegates: const [
              bullUiLocalizationsDelegate,
              ...settingsTestLocalizationsDelegates,
            ],
            supportedLocales: SettingsLocalizations.supportedLocales,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<SettingsCubit>.value(value: cubit),
                BitcoinPriceFixture.prices(
                  availableCurrencies: const ['CAD', 'USD', 'EUR'],
                ),
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
        expect(
          find.descendant(
            of: find.byType(BullPickerChip<bool>),
            matching: find.text('Bitcoin'),
          ),
          findsOneWidget,
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
        await tester.tap(find.byType(BullPickerChip<bool>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CAD').last);
        await tester.pumpAndSettle();
        verify(() => cubit.setStartAmountsInFiat(true)).called(1);
      } finally {
        semantics.dispose();
      }
    });
  }
}
