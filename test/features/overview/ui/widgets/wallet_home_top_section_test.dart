import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAmount,
        BullAmountScope,
        BullAmountSnapshot,
        BullHeaderBackground,
        BullQuickActionBar,
        BullShimmerBox,
        bullUiLocalizationsDelegate;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:overview/overview.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

const _actionsKey = ValueKey('home-quick-actions');

Future<void> _pump(
  WidgetTester tester, {
  int? total = 12345,
  bool? hide = false,
  bool chart = false,
  VoidCallback? closeChart,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: const [
        bullUiLocalizationsDelegate,
        ...appLocalizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BitcoinPriceFixture.prices(
            amountDisplay: (
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'CAD',
              hideAmounts: false,
            ),
            currency: 'CAD',
            bitcoinPrice: 100000,
          ),
        ],
        child: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 800),
              textScaler: TextScaler.linear(scale),
            ),
            child: BullAmountScope(
              snapshot: const BullAmountSnapshot(
                unit: BitcoinUnit.sats,
                hideAmounts: false,
                isReady: true,
              ),
              writeUnit: (_) async => true,
              child: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: WalletHomeTopSection(
                    background: AssetImage(Assets.backgrounds.bgRed.path),
                    totalSat: total,
                    isLoading: false,
                    hideAmounts: hide,
                    unavailableLabel: 'Balance unavailable',
                    onCurrencyChanged: (_, _) {},
                    showChart: chart,
                    chart: const Text('Price history'),
                    closeChartLabel: 'Back to balance',
                    onCloseChart: closeChart ?? () {},
                    actions: Builder(
                      builder: (context) => SizedBox(
                        key: _actionsKey,
                        height: BullQuickActionBar.heightOf(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('unknown balance differs from a proven zero', (tester) async {
    await _pump(tester, total: null);
    expect(find.text('Balance unavailable'), findsNWidgets(2));
    expect(find.byType(BullAmount), findsNothing);
    await _pump(tester, total: 0);
    expect(find.text('0 sats'), findsOneWidget);
    expect(find.text('Balance unavailable'), findsNothing);
    expect(find.byType(HomeFiatBalance), findsOneWidget);
    expect(find.byType(EyeToggle), findsNothing);
  });

  testWidgets('unknown or hidden preferences do not expose BTC or fiat', (
    tester,
  ) async {
    await _pump(tester);
    final visibleFiat = tester.widget<FiatAmountText>(
      find.byType(FiatAmountText),
    );
    expect(find.text('12,345 sats'), findsOneWidget);
    expect(visibleFiat.hideAmounts, isFalse);
    final quote = visibleFiat.formattedAmount;
    if (quote == null) throw StateError('Expected a readable fiat quote');
    for (final hide in <bool?>[true, null]) {
      await _pump(tester, hide: hide);
      expect(find.text('12,345 sats'), findsNothing);
      expect(find.text(quote), findsNothing);
      expect(
        tester.widget<FiatAmountText>(find.byType(FiatAmountText)).hideAmounts,
        isTrue,
      );
      expect(
        find.byType(BullShimmerBox),
        hide == null ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets(
    'chart replaces the amounts and closes via its translated label',
    (tester) async {
      var closed = false;
      await _pump(tester);
      await _pump(tester, chart: true, closeChart: () => closed = true);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Price history'), findsOneWidget);
      expect(find.byType(BullAmount), findsNothing);
      await tester.tap(find.byTooltip('Back to balance'));
      expect(closed, isTrue);
    },
  );

  testWidgets('background retains its quick-action overhang with large text', (
    tester,
  ) async {
    await _pump(tester, scale: 1.5);
    expect(tester.takeException(), isNull);
    final background = tester.getRect(find.byType(BullHeaderBackground));
    final actions = tester.getRect(find.byKey(_actionsKey));
    expect(
      background.height,
      greaterThanOrEqualTo(
        WalletHomeTopSection.minBackgroundHeight(
          tester.element(find.byType(WalletHomeTopSection)),
        ),
      ),
    );
    expect(background.bottom, closeTo(actions.center.dy, 0.01));
  });
}
