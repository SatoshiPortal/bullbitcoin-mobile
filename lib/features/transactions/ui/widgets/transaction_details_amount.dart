import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionDetailsAmount extends StatelessWidget {
  const TransactionDetailsAmount({super.key});

  @override
  Widget build(BuildContext context) {
    final tx = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.transaction,
    );
    final isOrder = tx?.isOrder ?? false;
    // A recovered swap's canonical tx may be the lockup (send) leg, so
    // swapDisplayAmountSat would headline the SENT amount. The cubit resolves
    // what the user actually received on the counterpart leg (claim or refund);
    // use it so a refund headlines the refunded amount, not the lockup.
    final isRecoveredSwap = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.isRecoveredSwap,
    );
    final recoveredReceivedSat = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.getAmountReceived(),
    );
    final amountSat = isRecoveredSwap
        ? recoveredReceivedSat
        : tx?.swapDisplayAmountSat;
    final orderAmountAndCurrency = tx?.order?.amountAndCurrencyToDisplay();
    final showOrderInFiat =
        isOrder &&
        tx?.order != null &&
        (tx!.order is FiatPaymentOrder ||
            tx.order is BalanceAdjustmentOrder ||
            tx.order is WithdrawOrder ||
            tx.order is FundingOrder);

    return Row(
      mainAxisAlignment: .center,
      children: [
        CurrencyText(
          isOrder && !showOrderInFiat && orderAmountAndCurrency != null
              ? orderAmountAndCurrency.$1.toInt()
              : amountSat ?? 0,
          showFiat: false,
          style: context.font.displaySmall?.copyWith(
            color: context.appColors.secondary,
            fontWeight: .w500,
          ),
          fiatAmount:
              isOrder && showOrderInFiat && orderAmountAndCurrency != null
              ? orderAmountAndCurrency.$1.toDouble()
              : null,
          fiatCurrency:
              isOrder && showOrderInFiat && orderAmountAndCurrency != null
              ? orderAmountAndCurrency.$2
              : null,
        ),
      ],
    );
  }
}
