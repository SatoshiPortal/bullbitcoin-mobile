import 'dart:io';

import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

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
  for (final dark in [false, true]) {
    for (final state in [
      'bitcoin',
      'fiat',
      'max',
      'optional',
      'no-price',
      'picker',
      'currency',
      'settings',
      'chip-menu',
      'pressed',
      'large-action',
    ]) {
      testWidgets('$state ${dark ? 'dark' : 'light'}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final colors = dark
            ? testBullTheme.copyWith(
                background: const Color(0xFF000000),
                surface: const Color(0xFF1C1C1E),
                surfaceContainer: const Color(0xFF2C2C2E),
                secondary: const Color(0xFFFFFFFF),
                onSecondary: const Color(0xFF15171C),
                text: const Color(0xFFFFFFFF),
                onSurface: const Color(0xFFFFFFFF),
                textMuted: const Color(0xFF8E8E93),
                border: const Color(0xFF58585A),
              )
            : testBullTheme;
        final controller = TextEditingController(
          text: state == 'optional' ? '' : '25000',
        );
        addTearDown(controller.dispose);
        final typography = BullTypography.standard.resolved(colors.text);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
                scaffoldBackgroundColor: colors.background,
                textTheme: typography.toTextTheme(),
                extensions: bullUiExtensions(
                  colors: colors,
                  brightness: dark ? Brightness.dark : Brightness.light,
                  typography: typography,
                ),
              ),
              localizationsDelegates: bullUiLocalizationsDelegates,
              supportedLocales: BullUiLocalizations.supportedLocales,
              home: Scaffold(
                body: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BullTopBar(title: 'Send'),
                      for (var step = 0; step < 3; step++)
                        BullStepBar(
                          labels: const ['Recipient', 'Amount', 'Confirm'],
                          currentStep: step,
                          semanticLabel: (index, label) =>
                              'Step ${index + 1}: $label',
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Amount', style: typography.body),
                            const Gap(8),
                            BullAmountInput(
                              framed: true,
                              canonicalUnit: BitcoinUnit.sats,
                              amountController: controller,
                              inCard: true,
                              initialCurrencyCode:
                                  state == 'fiat' || state == 'no-price'
                                  ? 'CAD'
                                  : null,
                              emptyEquivalent: state == 'optional'
                                  ? 'Optional'
                                  : null,
                              defaultCurrencyCode: 'CAD',
                              isMax: state == 'max',
                              maxAmountSat: BigInt.from(1249580),
                              currencies: [
                                BullAmountCurrency(
                                  code: 'CAD',
                                  decimals: 2,
                                  price: state == 'no-price' ? null : 125000,
                                  priceAt: DateTime.utc(2026, 11, 19, 14, 32),
                                ),
                                const BullAmountCurrency(
                                  code: 'EUR',
                                  decimals: 2,
                                ),
                              ],
                            ),
                            const Gap(8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                MediaQuery(
                                  data: MediaQueryData(
                                    textScaler: TextScaler.linear(
                                      state == 'large-action' ? 3 : 1,
                                    ),
                                  ),
                                  child: BullFieldAction(
                                    label: 'MAX',
                                    onPressed: () {},
                                  ),
                                ),
                                const Gap(8),
                                BullFieldAction(
                                  label: 'Edit recipient',
                                  icon: Icons.edit,
                                  onPressed: () {},
                                ),
                                const Gap(8),
                                BullFieldAction(
                                  label: 'Remove recipient',
                                  icon: Icons.delete_outline,
                                  onPressed: () {},
                                ),
                              ],
                            ),
                            if (state == 'chip-menu') ...[
                              const Gap(16),
                              BullPickerChip<String>(
                                value: 'btc',
                                onChanged: (_) {},
                                items: const [
                                  BullPickerItem(
                                    value: 'btc',
                                    label: 'Bitcoin units',
                                  ),
                                  BullPickerItem(
                                    value: 'fiat',
                                    label:
                                        'Fiat currencies with a longer label',
                                  ),
                                ],
                              ),
                            ],
                            if (state == 'settings') ...[
                              const Gap(16),
                              BullSettingsEntryTile(
                                label: 'Advanced settings',
                                summary: 'Custom network fee summary',
                                onPressed: () {},
                              ),
                            ],
                            if (state == 'picker') ...[
                              const Gap(16),
                              BullPickerRow(
                                label: 'bitcoin',
                                subtitle: 'Wallet you send from',
                                selected: true,
                                onPressed: () {},
                              ),
                              BullPickerRow(
                                label: 'Savings',
                                subtitle: 'New address',
                                selected: false,
                                onPressed: () {},
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (state == 'currency') {
          await tester.tap(find.byTooltip('Currency: Bitcoin'));
          await tester.pumpAndSettle();
        }
        if (state == 'chip-menu') {
          await tester.tap(find.text('Bitcoin units'));
          await tester.pumpAndSettle();
        }
        TestGesture? press;
        if (state == 'pressed') {
          press = await tester.startGesture(
            tester.getCenter(find.byTooltip('MAX')),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(key),
          matchesGoldenFile(
            'goldens/send-kit/$state-${dark ? 'dark' : 'light'}.png',
          ),
        );
        await press?.up();
      });
    }
  }
}
