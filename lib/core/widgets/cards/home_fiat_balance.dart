import 'package:bull_pricer/bull_pricer.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
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

  @override
  Widget build(BuildContext context) {
    final priceState = context.select((BitcoinPriceBloc b) => b.state);
    final loadingPrice = priceState.loadingPrice;
    final hasValid = priceState.hasValidFiatRate;

    // Only gate on balance/loading and whether we have a usable rate, not
    // [startupFailed], or a successful currency change still shows skeleton.
    final showSkeleton = showBalanceLoading || loadingPrice || !hasValid;

    final blocCurrencies = priceState.availableCurrencies;
    final currencies = blocCurrencies != null && blocCurrencies.isNotEmpty
        ? blocCurrencies
        : SupportedCurrency.codes;
    final currentCurrency = context.select(
      (SettingsCubit cubit) => cubit.state.currencyCode ?? 'CAD',
    );

    Widget picker(Widget child) => BullPickerMenu<String>(
      value: currentCurrency,
      items: [
        for (final code in currencies)
          BullPickerItem(
            value: code,
            label: '${SupportedCurrency.tryFromCode(code)?.flag ?? ''} $code',
          ),
      ],
      onChanged: (picked) {
        if (picked == currentCurrency) return;
        context.read<SettingsCubit>().changeCurrency(picked);
      },
      child: child,
    );

    if (showSkeleton) return picker(const _HomeFiatBalanceSkeleton());

    return picker(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.bullShapes.button),
          border: Border.all(
            color: context.appColors.border.withValues(alpha: 0.3),
          ),
          color: context.appColors.border.withValues(alpha: 0.3),
        ),
        child: CurrencyText(
          balanceSat,
          showFiat: true,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
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
        borderRadius: BorderRadius.circular(context.bullShapes.button),
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
              borderRadius: BorderRadius.circular(context.bullShapes.card),
            ),
          ),
        ),
      ),
    );
  }
}
