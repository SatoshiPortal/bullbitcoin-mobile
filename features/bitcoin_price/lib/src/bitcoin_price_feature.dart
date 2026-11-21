import 'dart:async';

import 'package:bitcoin_price/src/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bitcoin_price/src/presentation/cubit/price_chart_cubit.dart';
import 'package:bitcoin_price/src/ui/price_history_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';

import 'domain/usecases/get_bitcoin_price_usecase.dart';
import 'domain/usecases/get_price_history_usecase.dart';
import 'domain/usecases/read_price_currency_usecase.dart';
import 'domain/usecases/watch_bitcoin_price_amount_display_usecase.dart';
import 'domain/usecases/watch_price_currency_usecase.dart';

/// Composes the shared fiat display and independent chart sessions.
final class BitcoinPriceFeature {
  final BitcoinPriceBloc Function() _createPrices;
  final PriceChartCubit Function() _createChart;

  const BitcoinPriceFeature._(this._createPrices, this._createChart);

  factory BitcoinPriceFeature.mount({
    required ActiveEnvironmentReader environment,
    required AmountDisplayPreferencesReader amountDisplay,
    required RuntimeDisplayPreferencesReader display,
    IndexPriceReader? getIndexPrice,
    PriceHistoryReader? getPriceHistory,
  }) {
    final readCurrency = ReadPriceCurrencyUsecase(display);
    return BitcoinPriceFeature._(
      () => BitcoinPriceBloc(
        watchAmountDisplayUsecase: WatchBitcoinPriceAmountDisplayUsecase(
          amountDisplay,
        ),
        readPriceCurrencyUsecase: readCurrency,
        getBitcoinPriceUsecase: GetBitcoinPriceUsecase(
          environment: environment,
          getIndexPrice: getIndexPrice ?? Pricer.getIndexPrice,
        ),
        watchPriceCurrencyUsecase: WatchPriceCurrencyUsecase(display),
      ),
      () => PriceChartCubit(
        getPriceHistoryUsecase: GetPriceHistoryUsecase(
          getPriceHistory: getPriceHistory ?? Pricer.getPriceHistory,
        ),
        readPriceCurrencyUsecase: readCurrency,
      ),
    );
  }

  Widget providePrices({required Widget child}) => BlocProvider(
    create: (_) => _createPrices()..add(const BitcoinPriceStarted()),
    child: child,
  );

  Widget provideEmbeddedChart({required Widget child}) =>
      BlocProvider(create: (_) => _createChart(), child: child);

  List<RouteBase> get routes => [
    GoRoute(
      name: _historyRouteName,
      path: 'price-history',
      builder: (context, state) => BlocProvider(
        create: (_) => _createChart()..loadPriceHistory(),
        child: PriceHistoryScreen(onBack: () => context.pop()),
      ),
    ),
  ];

  static const _historyRouteName = 'priceHistory';

  static Future<void> openHistory(BuildContext context) =>
      context.pushNamed<void>(_historyRouteName);

  static String? watchFiatAmount(BuildContext context, int sats) => context
      .select((BitcoinPriceBloc bloc) => bloc.state.calculateFiatPrice(sats));

  static List<String>? watchCurrencies(BuildContext context) =>
      context.select((BitcoinPriceBloc bloc) => bloc.state.availableCurrencies);

  static void refresh(BuildContext context, {bool onlyIfUnavailable = false}) {
    final bloc = context.read<BitcoinPriceBloc>();
    if (onlyIfUnavailable &&
        (bloc.state.hasValidFiatRate || bloc.state.loadingPrice)) {
      return;
    }
    bloc.add(const BitcoinPriceFetched());
  }

  static void quoteInCurrency(BuildContext context, String currencyCode) =>
      context.read<BitcoinPriceBloc>().add(
        BitcoinPriceCurrencyChanged(currencyCode: currencyCode),
      );

  static bool watchChartVisible(BuildContext context) =>
      context.select((PriceChartCubit cubit) => cubit.state.showChart);

  static void showChart(BuildContext context) {
    unawaited(context.read<PriceChartCubit>().showChart());
  }

  static void hideChart(BuildContext context) =>
      context.read<PriceChartCubit>().hideChart();
}
