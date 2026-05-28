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
import 'package:shimmer/shimmer.dart';

class HomeFiatBalance extends StatelessWidget {
  const HomeFiatBalance({
    super.key,
    required this.balanceSat,
    this.showBalanceLoading = false,
  });

  final int balanceSat;

  /// When true (e.g. wallet list still loading), avoids showing fiat from 0 sats.
  final bool showBalanceLoading;

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
    final priceState = context.select((BitcoinPriceBloc b) => b.state);
    final loadingPrice = priceState.loadingPrice;
    final hasValid = priceState.hasValidFiatRate;

    // Only gate on balance/loading and whether we have a usable rate — not
    // [startupFailed], or a successful currency change still shows skeleton.
    final showSkeleton =
        showBalanceLoading || loadingPrice || !hasValid;

    if (showSkeleton) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openCurrencyBottomSheet(context),
        child: const _HomeFiatBalanceSkeleton(),
      );
    }

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

class _HomeFiatBalanceSkeleton extends StatelessWidget {
  const _HomeFiatBalanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: context.appColors.border.withValues(alpha: 0.3),
        ),
        color: context.appColors.border.withValues(alpha: 0.3),
      ),
      child: Shimmer.fromColors(
        baseColor: context.appColors.shimmerBase,
        highlightColor: context.appColors.shimmerHighlight,
        child: SizedBox(
          width: 140,
          height: 22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
