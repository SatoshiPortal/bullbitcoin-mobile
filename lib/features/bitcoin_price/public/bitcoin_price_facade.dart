import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_history_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

export 'fiat_amount_text.dart';
export 'home_fiat_balance.dart';
export '../ui/price_chart_widget.dart' show PriceChartWidget;

/// Price display and chart controls for consumers of this feature.
class BitcoinPriceFacade {
  const BitcoinPriceFacade(this._locator);

  final GetIt _locator;

  Widget providePrices({required Widget child}) => BlocProvider(
    create: (_) =>
        _locator<BitcoinPriceBloc>()..add(const BitcoinPriceStarted()),
    child: child,
  );

  Widget provideEmbeddedChart({required Widget child}) =>
      BlocProvider(create: (_) => _locator<PriceChartCubit>(), child: child);

  Widget buildHistory({required VoidCallback onBack}) => BlocProvider(
    create: (_) => _locator<PriceChartCubit>()..loadPriceHistory(),
    child: PriceHistoryScreen(onBack: onBack),
  );

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

  static Future<void> showChart(BuildContext context) =>
      context.read<PriceChartCubit>().showChart();

  static void hideChart(BuildContext context) =>
      context.read<PriceChartCubit>().hideChart();
}
