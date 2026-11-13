import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_history_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

/// Public entry point for the standalone price history.
class BitcoinPriceFacade {
  const BitcoinPriceFacade(this._locator);

  final GetIt _locator;

  Widget buildHistory({required VoidCallback onBack}) => BlocProvider(
    create: (_) => _locator<PriceChartCubit>()..loadPriceHistory(),
    child: PriceHistoryScreen(onBack: onBack),
  );
}
