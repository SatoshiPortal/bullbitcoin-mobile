import 'package:bb_mobile/localizations.dart' show appLocalizationsDelegates;
import 'package:bitcoin_price/bitcoin_price.dart'
    show BitcoinPriceLocalizations;
import 'package:preferences/preferences.dart' show Environment, SettingsEntity;
import 'package:bull_ui/app_theme.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:settings/testing.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/eye_toggle.dart';
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
        ...appLocalizationsDelegates,
        BitcoinPriceLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
        bullUiLocalizationsDelegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
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
