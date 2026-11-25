import 'dart:async';

import 'package:bull_ui/bull_ui.dart'
    show BullInlineTextButton, BullText, BullThemeX, BullTypographyX;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:transactions/src/domain/entities/transaction_history.dart';
import 'package:transactions/src/presentation/blocs/transactions_cubit.dart';
import 'package:transactions/src/presentation/transactions_localizations_x.dart';

/// Says that the list holds wallet activity only because the exchange orders
/// could not be read, with a Retry that reloads the history.
class ExchangeOrdersNotice extends StatelessWidget {
  const ExchangeOrdersNotice({super.key});

  static bool shows(ExchangeOrdersInHistory? read) => switch (read) {
    ExchangeOrdersUnavailable() => true,
    null ||
    ExchangeOrdersMerged() ||
    ExchangeOrdersNoAccount() ||
    ExchangeOrdersNotOffered() => false,
  };

  @override
  Widget build(BuildContext context) {
    final read = context.select(
      (TransactionsCubit cubit) => cubit.state.exchangeOrders,
    );
    if (!shows(read)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: BullText(
              context.loc.transactionListExchangeOrdersUnavailable,
              style: context.bullType.body,
              color: context.bull.error,
            ),
          ),
          BullInlineTextButton(
            onPressed: () =>
                unawaited(context.read<TransactionsCubit>().loadTxs()),
            child: BullText(context.loc.retry, style: context.bullType.label),
          ),
        ],
      ),
    );
  }
}
