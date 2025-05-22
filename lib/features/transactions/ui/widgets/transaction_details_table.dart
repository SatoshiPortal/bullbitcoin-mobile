import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/transactions/blocs/transaction_details/transaction_details_cubit.dart';
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
    final swapFees =
        (swap?.fees?.claimFee ?? 0) +
        (swap?.fees?.boltzFee ?? 0) +
        (swap?.fees?.lockupFee ?? 0);
    final payjoin = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.payjoin,
    );

    final labels = tx?.labels.join(', ') ?? '';
    final address = tx?.toAddress ?? '';
    final txId = tx?.txId ?? '';
    final abbreviatedAddress = StringFormatting.truncateMiddle(address);
    final addressLabels = tx?.toAddressLabels?.join(', ') ?? '';
    final abbreviatedTxId = StringFormatting.truncateMiddle(txId);
    final bitcoinUnit = context.select(
      (SettingsCubit cubit) => cubit.state?.bitcoinUnit,
    );

    return DetailsTable(
      items: [
        // TODO(kumulynja): Make the value of the DetailsTableItem be a widget instead of a string
        // to be able to use the CurrencyText widget instead of having to format the amount here.
        DetailsTableItem(
          label:
              tx?.isIncoming != null
                  ? tx!.isIncoming
                      ? 'Amount received'
                      : 'Amount sent'
                  : 'Amount',
          displayValue:
              bitcoinUnit == BitcoinUnit.sats
                  ? FormatAmount.sats(amountSat).toUpperCase()
                  : FormatAmount.btc(
                    ConvertAmount.satsToBtc(amountSat),
                  ).toUpperCase(),
        ),
        if (tx?.isToSelf == true)
          DetailsTableItem(
            label: 'Amount received',
            displayValue:
                bitcoinUnit == BitcoinUnit.sats
                    ? FormatAmount.sats(amountSat).toUpperCase()
                    : FormatAmount.btc(
                      ConvertAmount.satsToBtc(amountSat),
                    ).toUpperCase(),
          ),
        if (tx?.isOutgoing == true)
          DetailsTableItem(
            label: 'Transaction Fee',
            displayValue:
                bitcoinUnit == BitcoinUnit.sats
                    ? FormatAmount.sats(tx?.feeSat ?? 0).toUpperCase()
                    : FormatAmount.btc(
                      ConvertAmount.satsToBtc(tx?.feeSat ?? 0),
                    ).toUpperCase(),
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
        DetailsTableItem(
          label: 'Status',
          displayValue: tx?.status.displayName ?? '',
        ),
        if (tx?.confirmationTime != null)
          DetailsTableItem(
            label: 'Confirmation time',
            displayValue: DateFormat(
              'MMM d, y, h:mm a',
            ).format(tx!.confirmationTime!),
          ),
        if (abbreviatedAddress.isNotEmpty)
          DetailsTableItem(
            label: 'Address',
            displayValue: abbreviatedAddress,
            copyValue: address,
          ),
        if (addressLabels.isNotEmpty)
          DetailsTableItem(label: 'Address notes', displayValue: addressLabels),
        DetailsTableItem(
          label: 'Transaction ID',
          displayValue: abbreviatedTxId,
          copyValue: txId,
        ),
        if (labels.isNotEmpty)
          DetailsTableItem(label: 'Transaction notes', displayValue: labels),
        if (swap != null) ...[
          DetailsTableItem(
            label: 'Swap status',
            displayValue: swap.status.displayName,
          ),
          DetailsTableItem(
            label: 'Swap ID',
            displayValue: swap.id,
            copyValue: swap.id,
          ),
          if (swap.completionTime != null)
            DetailsTableItem(
              label: 'Swap time received',
              displayValue: DateFormat(
                'MMM d, y, h:mm a',
              ).format(swap.completionTime!),
            ),
          if (swap.fees != null)
            DetailsTableItem(
              label: 'Total Swap fees',
              displayValue:
                  bitcoinUnit == BitcoinUnit.sats
                      ? FormatAmount.sats(swapFees).toUpperCase()
                      : FormatAmount.btc(
                        ConvertAmount.satsToBtc(swapFees),
                      ).toUpperCase(),
            ),
        ],
        if (payjoin != null) ...[
          DetailsTableItem(
            label: 'Payjoin status',
            displayValue:
                payjoin.isCompleted
                    ? 'Completed'
                    : payjoin.isExpired
                    ? 'Expired'
                    : payjoin.status.name,
          ),
          DetailsTableItem(
            label: 'Payjoin creation time',
            displayValue: DateFormat(
              'MMM d, y, h:mm a',
            ).format(payjoin.createdAt),
          ),
        ],
      ],
    );
  }
}
