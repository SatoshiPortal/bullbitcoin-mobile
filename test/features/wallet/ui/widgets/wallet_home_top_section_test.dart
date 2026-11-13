import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_top_section.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Wallet extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _Settings extends MockCubit<SettingsState> implements SettingsCubit {}

class _Price extends MockBloc<BitcoinPriceEvent, BitcoinPriceState>
    implements BitcoinPriceBloc {}

class _Chart extends MockCubit<PriceChartState> implements PriceChartCubit {}

void main() {
  testWidgets(
    'balance grows for unconfirmed amount at 200 percent text scale',
    (tester) async {
      final wallet = _Wallet();
      final settings = _Settings();
      final price = _Price();
      final chart = _Chart();
      whenListen(
        wallet,
        const Stream<WalletState>.empty(),
        initialState: const WalletState(
          status: WalletStatus.success,
          unconfirmedIncomingBalance: 100,
        ),
      );
      whenListen(
        settings,
        const Stream<SettingsState>.empty(),
        initialState: const SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.btc,
            currencyCode: 'CAD',
            hideAmounts: true,
          ),
        ),
      );
      whenListen(
        price,
        const Stream<BitcoinPriceState>.empty(),
        initialState: const BitcoinPriceState(
          currency: 'CAD',
          bitcoinPrice: 100000,
        ),
      );
      whenListen(
        chart,
        const Stream<PriceChartState>.empty(),
        initialState: const PriceChartState(),
      );
      const actionKey = ValueKey('actions');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(2),
              ),
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<WalletBloc>.value(value: wallet),
                  BlocProvider<SettingsCubit>.value(value: settings),
                  BlocProvider<BitcoinPriceBloc>.value(value: price),
                  BlocProvider<PriceChartCubit>.value(value: chart),
                ],
                child: const SingleChildScrollView(
                  child: SizedBox(
                    width: 360,
                    child: WalletHomeTopSection(
                      actions: SizedBox(key: actionKey, height: 40),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final unconfirmed = find.text(l10n.walletBalanceUnconfirmedIncoming);
      expect(unconfirmed, findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(actionKey)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(unconfirmed).dy + 12),
      );
      expect(tester.getTopLeft(find.byKey(actionKey)).dy, greaterThan(224));
    },
  );
}
