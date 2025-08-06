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
    final amountSat = tx?.amountSat;
    final orderAmountAndCurrency = tx?.order?.amountAndCurrencyToDisplay();
    final showOrderInFiat =
        isOrder &&
        (tx!.order is FiatPaymentOrder ||
            tx.order is BalanceAdjustmentOrder ||
            tx.order is WithdrawOrder ||
            tx.order is FundingOrder);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CurrencyText(
          isOrder && !showOrderInFiat && orderAmountAndCurrency != null
              ? orderAmountAndCurrency.$1.toInt()
              : amountSat ?? 0,
          showFiat: false,
          style: context.font.displaySmall?.copyWith(
            color: context.colour.outlineVariant,
            fontWeight: FontWeight.w500,
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
