import 'package:bitcoin_price/bitcoin_price.dart'
    show BitcoinPriceLocalizations;
import 'package:flutter/rendering.dart';
import 'package:preferences/preferences.dart' show Environment, SettingsEntity;
import 'package:bull_ui/app_theme.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/eye_toggle.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_app_bar.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_top_section.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAmountScope,
        BullAmountSnapshot,
        BullQuickActionBar,
        bullUiLocalizationsDelegate;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _Wallet extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _Settings extends MockCubit<SettingsState> implements SettingsCubit {}

const _actionKey = ValueKey('actions');

Future<void> _pumpTopSection(
  WidgetTester tester, {
  required double textScale,
  bool hideAmounts = true,
  VoidCallback? onSettings,
  double? actionsHeight,
  required int unconfirmedIncomingBalance,
}) async {
  final wallet = _Wallet();
  final settings = _Settings();

  final amountDisplay = (
    bitcoinUnit: BitcoinUnit.btc,
    currencyCode: 'CAD',
    hideAmounts: hideAmounts,
  );
  whenListen(
    wallet,
    const Stream<WalletState>.empty(),
    initialState: WalletState(
      amountDisplay: amountDisplay,
      status: WalletStatus.success,
      unconfirmedIncomingBalance: unconfirmedIncomingBalance,
    ),
  );
  whenListen(
    settings,
    const Stream<SettingsState>.empty(),
    initialState: SettingsState(
      storedSettings: SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'CAD',
        hideAmounts: hideAmounts,
      ),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: [
        ...AppLocalizations.localizationsDelegates,
        BitcoinPriceLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
        bullUiLocalizationsDelegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: onSettings == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: BlocProvider<SettingsCubit>.value(
                  value: settings,
                  child: WalletHomeAppBar(onSettings: onSettings),
                ),
              ),
        body: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: MultiBlocProvider(
            providers: [
              BlocProvider<WalletBloc>.value(value: wallet),
              BlocProvider<SettingsCubit>.value(value: settings),
              BitcoinPriceFixture.prices(
                amountDisplay: amountDisplay,
                currency: 'CAD',
                bitcoinPrice: 100000,
              ),
              BitcoinPriceFixture.chart(),
            ],
            child: BullAmountScope(
              snapshot: BullAmountSnapshot(
                unit: BitcoinUnit.btc,
                hideAmounts: hideAmounts,
                isReady: true,
              ),
              writeUnit: (_) async => true,
              child: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: WalletHomeTopSection(
                    actions: Builder(
                      builder: (context) => SizedBox(
                        key: _actionKey,
                        height:
                            actionsHeight ??
                            BullQuickActionBar.heightOf(context),
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
  await tester.pump();
}

void main() {
  testWidgets('Bitcoin and fiat amounts share typography and unit alignment', (
    tester,
  ) async {
    for (final scale in [1.0, 2.0]) {
      await _pumpTopSection(
        tester,
        textScale: scale,
        unconfirmedIncomingBalance: 0,
      );
      Rect textRect(String unit, {bool entireLine = false}) {
        final finder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().endsWith(' $unit'),
        );
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        final text = paragraph.text.toPlainText();
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(
                baseOffset: entireLine ? 0 : text.length - unit.length,
                extentOffset: text.length,
              ),
            )
            .single
            .toRect();
        return box.shift(paragraph.localToGlobal(Offset.zero));
      }

      final bitcoin = textRect('BTC');
      final fiat = textRect('CAD');
      expect(bitcoin.height, closeTo(fiat.height, 0.01));
      expect(bitcoin.right, closeTo(fiat.right, 0.01));
      expect(
        textRect('BTC', entireLine: true).height,
        closeTo(textRect('CAD', entireLine: true).height, 0.01),
      );
    }
  });

  testWidgets(
    'Balance frames match in size with neutral fiat and orange Bitcoin tints',
    (tester) async {
      for (final hidden in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          await _pumpTopSection(
            tester,
            textScale: scale,
            hideAmounts: hidden,
            unconfirmedIncomingBalance: 0,
          );
          Finder amount(String unit) => find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().endsWith(' $unit'),
          );
          Finder frame(String unit) => find
              .ancestor(of: amount(unit), matching: find.byType(DecoratedBox))
              .first;
          expect(tester.getSize(frame('BTC')), tester.getSize(frame('CAD')));
          final bitcoin =
              tester.widget<DecoratedBox>(frame('BTC')).decoration
                  as BoxDecoration;
          final fiat =
              tester.widget<DecoratedBox>(frame('CAD')).decoration
                  as BoxDecoration;
          final colors = tester.element(amount('CAD')).appColors;
          expect(fiat.color, colors.border.withValues(alpha: 0.3));
          expect(bitcoin.color, colors.bitcoinOrange.withValues(alpha: 0.3));
          expect(
            fiat.border,
            Border.all(color: colors.border.withValues(alpha: 0.3)),
          );
          expect(
            bitcoin.border,
            Border.all(color: colors.bitcoinOrange.withValues(alpha: 0.3)),
          );
          expect(bitcoin.borderRadius, fiat.borderRadius);
          final btcText =
              tester.renderObject<RenderParagraph>(amount('BTC')).text
                  as TextSpan;
          final fiatText =
              tester.renderObject<RenderParagraph>(amount('CAD')).text
                  as TextSpan;
          expect(btcText.style?.color, colors.onPrimary);
          expect(fiatText.style?.color, colors.onPrimary);
        }
      }
    },
  );

  testWidgets('top bar settings gear is named and opens settings', (
    tester,
  ) async {
    var opened = false;
    await _pumpTopSection(
      tester,
      textScale: 1,
      unconfirmedIncomingBalance: 0,
      onSettings: () => opened = true,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final gear = find.byTooltip(l10n.settingsScreenTitle);
    expect(tester.getSize(gear).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(gear).height, greaterThanOrEqualTo(48));
    await tester.tap(gear);
    expect(opened, isTrue);
  });

  testWidgets('home balance has no eye toggle', (tester) async {
    await _pumpTopSection(
      tester,
      textScale: 1,
      actionsHeight: 100,
      unconfirmedIncomingBalance: 0,
    );
    expect(find.byType(EyeToggle), findsNothing);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byTooltip(l10n.walletShowAmountsTooltip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'balance grows for unconfirmed amount at 200 percent text scale',
    (tester) async {
      await _pumpTopSection(
        tester,
        textScale: 2,
        actionsHeight: 100,
        unconfirmedIncomingBalance: 100,
      );
      expect(tester.takeException(), isNull);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final unconfirmed = find.text(l10n.walletBalanceUnconfirmedIncoming);
      expect(unconfirmed, findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(_actionKey)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(unconfirmed).dy + 12),
      );
      expect(tester.getTopLeft(find.byKey(_actionKey)).dy, greaterThan(224));
      // The actions straddle the bottom edge of the background image.
      final backgroundBottom = tester.getBottomLeft(find.byType(Image)).dy;
      expect(
        backgroundBottom,
        greaterThan(tester.getTopLeft(find.byKey(_actionKey)).dy),
      );
      expect(
        backgroundBottom,
        lessThan(tester.getBottomLeft(find.byKey(_actionKey)).dy),
      );
    },
  );

  testWidgets(
    'background image is minBackgroundHeight tall with the quick action bar',
    (tester) async {
      // The home screen sizes its overscroll backdrop from this constant; a
      // taller backdrop shows below the image.
      await _pumpTopSection(
        tester,
        textScale: 1,
        unconfirmedIncomingBalance: 0,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(Image)).height,
        WalletHomeTopSection.minBackgroundHeight(
          tester.element(find.byType(WalletHomeTopSection)),
        ),
      );
    },
  );
}
