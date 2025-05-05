import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/features/transactions/bloc/transaction_details_cubit.dart';
import 'package:bb_mobile/ui/components/tables/details_table.dart';
import 'package:bb_mobile/ui/components/tables/details_table_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class TransactionDetailsTable extends StatelessWidget {
  const TransactionDetailsTable({super.key});

  @override
  Widget build(BuildContext context) {
    // The tx state can still change from pending to confirmed, so watch the state
    final tx = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.transaction,
    );
    final amountSat = tx?.amountSat ?? 0;
    final wallet = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.wallet,
    );
    final swap = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.swap,
    );
    final payjoin = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.payjoin,
    );

    final labels = tx?.labels.join(', ') ?? '';
    final address = tx?.toAddress ?? '';
    final txId = tx?.txId ?? '';
    final abbreviatedAddress = StringFormatting.truncateMiddle(address);
    final abbreviatedTxId = StringFormatting.truncateMiddle(txId);

    return DetailsTable(
      items: [
        DetailsTableItem(
          label: 'Amount received',
          displayValue: FormatAmount.sats(amountSat).toUpperCase(),
        ),
        DetailsTableItem(
          label: 'Wallet',
          displayValue:
              wallet != null
                  ? wallet.isLiquid
                      ? 'Instant Payments'
                      : 'Secure Bitcoin'
                  : '',
        ),

        DetailsTableItem(label: 'Status', displayValue: tx?.status.name ?? ''),
        if (tx?.confirmationTime != null)
          DetailsTableItem(
            label: 'Confirmation time',
            displayValue: DateFormat(
              'MMM d, y, h:mm a',
            ).format(tx!.confirmationTime!),
          ),
        DetailsTableItem(
          label: 'Address',
          displayValue: abbreviatedAddress,
          copyValue: address,
        ),
        DetailsTableItem(
          label: 'Transaction ID',
          displayValue: abbreviatedTxId,
          copyValue: txId,
        ),
        if (labels.isNotEmpty)
          DetailsTableItem(label: 'Note', displayValue: labels),
        if (swap != null) ...[
          DetailsTableItem(
            label: 'Swap status',
            displayValue: swap.status.name,
          ),
          DetailsTableItem(
            label: 'Swap ID',
            displayValue: swap.id,
            copyValue: swap.id,
          ),
          if (swap.completionTime != null)
            DetailsTableItem(
              label: 'Time received',
              displayValue: DateFormat(
                'MMM d, y, h:mm a',
              ).format(swap.completionTime!),
            ),
        ],
      ],
    );
  }
}
