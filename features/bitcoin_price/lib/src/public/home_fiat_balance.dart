import 'package:bull_pricer/bull_pricer.dart';
import 'package:bitcoin_price/src/l10n/bitcoin_price_localizations_x.dart';
import 'package:bitcoin_price/src/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import 'fiat_amount_text.dart';

class HomeFiatBalance extends StatelessWidget {
  const HomeFiatBalance({
    super.key,
    required this.balanceSat,
    required this.onCurrencyChanged,
    this.showBalanceLoading = false,
    this.forceHideAmounts = false,
    this.frameBuilder,
  });

  final int balanceSat;
  final void Function(BuildContext context, String currency) onCurrencyChanged;

  /// Custom presentation around the amount, retaining the currency picker.
  final Widget Function(BuildContext context, Widget child)? frameBuilder;

  /// When true (e.g. wallet list still loading), avoids showing fiat from 0 sats.
  final bool showBalanceLoading;
  final bool forceHideAmounts;

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
    final currentCurrency = priceState.amountDisplay?.currencyCode ?? 'CAD';

    Widget picker(Widget child) => BullPickerMenu<String>(
      tooltip: context.loc.currencySettingsDefaultFiatCurrencyLabel,
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
        onCurrencyChanged(context, picked);
      },
      child: child,
    );

    final amount = showSkeleton
        ? const _HomeFiatBalanceSkeleton()
        : FiatAmountText(
            formattedAmount: priceState.calculateFiatPrice(balanceSat),
            hideAmounts:
                forceHideAmounts ||
                (priceState.amountDisplay?.hideAmounts ?? true),
            style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
            color: context.bull.onPrimary,
          );
    return picker(
      frameBuilder?.call(context, amount) ??
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.bullShapes.button),
              border: Border.all(
                color: context.bull.border.withValues(alpha: 0.3),
              ),
              color: context.bull.border.withValues(alpha: 0.3),
            ),
            child: amount,
          ),
    );
  }
}

class _HomeFiatBalanceSkeleton extends StatelessWidget {
  const _HomeFiatBalanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.bull.shimmerBase,
      highlightColor: context.bull.shimmerHighlight,
      child: SizedBox(
        width: 140,
        height: 22,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.bull.surface,
            borderRadius: BorderRadius.circular(context.bullShapes.card),
          ),
        ),
      ),
    );
  }
}
