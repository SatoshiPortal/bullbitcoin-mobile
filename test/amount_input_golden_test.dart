import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });
  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    for (final variant in ['bitcoin', 'fiat', 'list', 'no-price', 'max']) {
      testWidgets('amount $variant ${theme.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 520);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final canonical = TextEditingController(
          text: variant == 'max' ? '1249580' : '25000',
        );
        addTearDown(canonical.dispose);
        final key = GlobalKey();
        final fiat = variant == 'fiat' || variant == 'no-price';
        final boundary = RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.themeData(theme),
            localizationsDelegates: bullUiLocalizationsDelegates,
            supportedLocales: BullUiLocalizations.supportedLocales,
            home: Scaffold(
              body: BullAmountScope(
                snapshot: const BullAmountSnapshot(
                  unit: BitcoinUnit.sats,
                  hideAmounts: false,
                  isReady: true,
                  defaultCurrencyCode: 'CAD',
                ),
                writeUnit: (_) async => true,
                writeInputMode: (_) async => true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: BullAmountInput(
                    canonicalUnit: BitcoinUnit.sats,
                    amountController: canonical,
                    initialCurrencyCode: fiat ? 'CAD' : null,
                    isMax: variant == 'max',
                    maxAmountSat: variant == 'max'
                        ? BigInt.from(1249580)
                        : null,
                    currencies: [
                      BullAmountCurrency(
                        code: 'CAD',
                        decimals: 2,
                        price: variant == 'no-price' ? null : 125000,
                        priceAt: DateTime.utc(2026, 11, 19, 14, 32),
                      ),
                      BullAmountCurrency(
                        code: 'USD',
                        decimals: 2,
                        price: 90000,
                        priceAt: DateTime.utc(2026, 11, 19, 14, 32),
                      ),
                      const BullAmountCurrency(code: 'EUR', decimals: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(boundary);
        await tester.pumpAndSettle();
        if (variant == 'list') {
          await tester.tap(find.byTooltip('Currency: Bitcoin'));
          await tester.pumpAndSettle();
          expect(find.text('No price available'), findsOneWidget);
          expect(find.text('Always start in Bitcoin'), findsNothing);
          expect(find.text('Enter amount in'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
        await expectLater(
          find.byKey(key),
          matchesGoldenFile('goldens/amount-input-$variant-${theme.name}.png'),
        );
      });
    }
  }
}
