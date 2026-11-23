import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapAmountInput extends StatelessWidget {
  const SwapAmountInput({
    super.key,
    required this.amountController,
    required this.focusNode,
  });

  final TextEditingController amountController;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransferBloc>().state;
    final limits = state.swapLimits;
    final max = state.maxAmountSat;
    final error = switch (state.amountValidationError) {
      AmountValidationError.minimum when limits != null =>
        context.loc.swapErrorAmountBelowMinimum('${limits.min}'),
      AmountValidationError.maximum when limits != null =>
        context.loc.swapErrorAmountAboveMaximum('${limits.max}'),
      _ =>
        state.isInsufficientBalance ? context.loc.swapInsufficientFunds : null,
    };
    final input = BullAmountInput(
      canonicalUnit: state.bitcoinUnit,
      amountController: amountController,
      focusNode: focusNode,
      inCard: true,
      framed: true,
      readOnly: state.continueClicked || state.isCreatingSwap,
      defaultCurrencyCode: state.fiatCurrencyCode,
      isLiquid: state.fromWallet?.isLiquid == true,
      isMax: state.isMaxSelected,
      maxLoading: state.isMaxSelected && state.maxAmountSat == null,
      maxAmountSat: max == null ? null : BigInt.from(max),
      currencies: [
        for (final currency in SupportedCurrency.values)
          BullAmountCurrency(
            code: currency.code,
            decimals: currency.decimals,
            price: state.amountQuotes[currency]?.fiatAmount,
            priceAt: state.amountQuotes[currency]?.fetchedAt,
          ),
      ],
      onEntryChanged: (entry) => context.read<TransferBloc>().add(
        TransferAmountEntryChanged(
          sats: entry.sats,
          currencyCode: entry.currencyCode,
          text: entry.text,
          rate: entry.price,
          quotedAt: entry.priceAt,
          isValid: entry.isValid,
          isEdit: entry.isEdit,
        ),
      ),
      error: error,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.swapAmountLabel,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
        ),
        const Gap(BullSpacing.xs),
        input,
      ],
    );
  }
}
