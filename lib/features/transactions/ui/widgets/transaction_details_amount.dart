import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/view_models/transaction_detail_view_model.dart';
import 'package:flutter/widgets.dart';

class TransactionDetailsAmount extends StatelessWidget {
  const TransactionDetailsAmount({super.key, required this.amount});

  final TxAmountView amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CurrencyText(
          amount.isFiat ? 0 : amount.sats,
          showFiat: false,
          fiatAmount: amount.fiatAmount,
          fiatCurrency: amount.fiatCurrency,
          style: context.font.displaySmall?.copyWith(
            color: context.appColors.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
