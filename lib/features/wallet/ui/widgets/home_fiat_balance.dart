import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeFiatBalance extends StatelessWidget {
  const HomeFiatBalance({super.key, required this.balanceSat});

  final int balanceSat;

  Future<void> _openCurrencyBottomSheet(BuildContext context) async {
    List<String> availableCurrencies;

    try {
      final blocState = context.read<BitcoinPriceBloc>().state;
      if (blocState.availableCurrencies != null &&
          blocState.availableCurrencies!.isNotEmpty) {
        availableCurrencies = blocState.availableCurrencies!;
      } else {
        final usecase = locator<GetAvailableCurrenciesUsecase>();
        availableCurrencies = await usecase.execute();
      }
    } catch (e) {
      return;
    }

    if (availableCurrencies.isEmpty || !context.mounted) {
      return;
    }

    final currentCurrency =
        context.read<SettingsCubit>().state.currencyCode ?? 'CAD';

    final selectedCurrency = await BlurredBottomSheet.show<String?>(
      context: context,
      child: CurrencyBottomSheet(
        availableCurrencies: availableCurrencies,
        selectedValue: currentCurrency,
      ),
    );

    if (selectedCurrency != null &&
        selectedCurrency != currentCurrency &&
        context.mounted) {
      await context.read<SettingsCubit>().changeCurrency(selectedCurrency);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fiatPriceIsNull = context.select(
      (BitcoinPriceBloc bitcoinPriceBloc) =>
          bitcoinPriceBloc.state.bitcoinPrice == null,
    );

    if (fiatPriceIsNull) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openCurrencyBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: context.appColors.border.withValues(alpha: 0.3),
          ),
          color: context.appColors.border.withValues(alpha: 0.3),
        ),
        child: CurrencyText(
          balanceSat,
          showFiat: true,
          style: context.font.bodyLarge,
          color: context.appColors.onPrimary,
        ),
      ),
    );
  }
}
