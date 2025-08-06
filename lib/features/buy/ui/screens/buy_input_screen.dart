import 'package:bb_mobile/core/exchange/domain/errors/buy_error.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_amount_input_fields.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_destination_input_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BuyInputScreen extends StatelessWidget {
  const BuyInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final canCreateOrder = context.select(
      (BuyBloc bloc) => bloc.state.canCreateOrder,
    );
    final isCreatingOrder = context.select(
      (BuyBloc bloc) => bloc.state.isCreatingOrder,
    );
    final belowMinAmountError = context.select((BuyBloc bloc) {
      final error = bloc.state.createOrderBuyError;
      return error is BelowMinAmountBuyError ? error : null;
    });
    final aboveMaxAmountError = context.select((BuyBloc bloc) {
      final error = bloc.state.createOrderBuyError;
      return error is AboveMaxAmountBuyError ? error : null;
    });
    final insufficientFunds = context.select(
      (BuyBloc bloc) => bloc.state.isBalanceTooLow,
    );

    return Scaffold(
      appBar: AppBar(
        // Adding the leading icon button here manually since we are in the first
        // route of a shellroute and so no back button is provided by default.
        leading:
            context.canPop()
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    context.pop();
                  },
                )
                : null,
        title: const Text('Buy Bitcoin'),
      ),
      body: SafeArea(
        child: ScrollableColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(24),
            const BuyAmountInputFields(),
            const Gap(16.0),
            const BuyDestinationInputFields(),
            const Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCreatingOrder)
                  const Center(child: CircularProgressIndicator()),
                if (belowMinAmountError != null || aboveMaxAmountError != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        belowMinAmountError != null
                            ? 'You should buy at least'
                            : "You can't buy more than",
                        style: context.font.bodyMedium?.copyWith(
                          color: context.colour.error,
                        ),
                      ),
                      const Gap(4),
                      CurrencyText(
                        belowMinAmountError != null
                            ? belowMinAmountError.minAmountSat
                            : aboveMaxAmountError!.maxAmountSat,
                        showFiat: false,
                        style: context.font.bodyMedium?.copyWith(
                          color: context.colour.error,
                        ),
                      ),
                    ],
                  ),
                if (insufficientFunds)
                  Text(
                    'You do not have enough balance to create this order.',
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.error,
                    ),
                  ),
                const Gap(16),
                BBButton.big(
                  label: 'Continue',
                  disabled: !canCreateOrder || isCreatingOrder,
                  onPressed: () {
                    context.read<BuyBloc>().add(const BuyEvent.createOrder());
                  },
                  bgColor: context.colour.secondary,
                  textColor: context.colour.onSecondary,
                ),
                const Gap(16.0),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
