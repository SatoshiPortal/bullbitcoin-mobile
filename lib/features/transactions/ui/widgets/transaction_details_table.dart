import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/ui/components/tables/details_table.dart';
import 'package:bb_mobile/ui/components/tables/details_table_item.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class TransactionDetailsTable extends StatelessWidget {
  const TransactionDetailsTable({super.key});

  @override
  Widget build(BuildContext context) {
    // The tx state can still change from pending to confirmed, so watch the state
    final tx = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.transaction,
    );
    final walletTransaction = tx.walletTransaction;
    final swap = tx.swap;
    final payjoin = tx.payjoin;
    final amountSat = tx.amountSat;

    final wallet = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.wallet,
    );
    final walletLabel =
        wallet?.label ??
        (wallet?.isLiquid == true ? 'Instant Payments' : 'Secure Bitcoin');
    final counterpartWallet = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.counterpartWallet,
    );
    final counterpartWalletLabel =
        counterpartWallet != null
            ? counterpartWallet.label ??
                (counterpartWallet.isLiquid == true
                    ? 'Instant Payments'
                    : 'Secure Bitcoin')
            : null;

    final swapFees =
        (swap?.fees?.claimFee ?? 0) +
        (swap?.fees?.boltzFee ?? 0) +
        (swap?.fees?.lockupFee ?? 0);
    final swapCounterpartTransaction = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.swapCounterpartTransaction,
    );
    final abbreviatedSwapCounterpartTransactionTxId =
        swapCounterpartTransaction?.txId != null
            ? StringFormatting.truncateMiddle(swapCounterpartTransaction!.txId!)
            : '';

    final labels = tx.labels?.join(', ') ?? '';
    final address = walletTransaction?.toAddress ?? '';
    final txId = tx.txId ?? '';
    final abbreviatedAddress = StringFormatting.truncateMiddle(address);
    final addressLabels = walletTransaction?.toAddressLabels?.join(', ') ?? '';
    final abbreviatedTxId = StringFormatting.truncateMiddle(txId);
    final bitcoinUnit = context.select(
      (SettingsCubit cubit) => cubit.state.bitcoinUnit,
    );

    return DetailsTable(
      items: [
        DetailsTableItem(
          label: 'Transaction ID',
          displayValue: abbreviatedTxId,
          copyValue: txId,
        ),
        if (labels.isNotEmpty)
          DetailsTableItem(label: 'Transaction notes', displayValue: labels),
        if (walletLabel.isNotEmpty)
          DetailsTableItem(
            label: tx.isIncoming ? 'To wallet' : 'From wallet',
            displayValue: walletLabel,
          ),
        if (!tx.isSwap &&
            counterpartWalletLabel != null &&
            counterpartWalletLabel.isNotEmpty)
          DetailsTableItem(
            label: tx.isOutgoing ? 'To wallet' : 'From wallet',
            displayValue: counterpartWalletLabel,
          ),
        if (abbreviatedAddress.isNotEmpty)
          DetailsTableItem(
            label: 'Address',
            displayValue: abbreviatedAddress,
            copyValue: address,
          ),
        if (addressLabels.isNotEmpty)
          DetailsTableItem(label: 'Address notes', displayValue: addressLabels),
        // TODO(kumulynja): Make the value of the DetailsTableItem be a widget instead of a string
        // to be able to use the CurrencyText widget instead of having to format the amount here.
        DetailsTableItem(
          label: tx.isIncoming ? 'Amount received' : 'Amount sent',
          displayValue:
              bitcoinUnit == BitcoinUnit.sats
                  ? FormatAmount.sats(amountSat).toUpperCase()
                  : FormatAmount.btc(
                    ConvertAmount.satsToBtc(amountSat),
                  ).toUpperCase(),
        ),
        if (walletTransaction != null) ...[
          if (walletTransaction.isToSelf == true)
            DetailsTableItem(
              label: 'Amount received',
              displayValue:
                  bitcoinUnit == BitcoinUnit.sats
                      ? FormatAmount.sats(amountSat).toUpperCase()
                      : FormatAmount.btc(
                        ConvertAmount.satsToBtc(amountSat),
                      ).toUpperCase(),
            ),
          if (tx.isOutgoing == true)
            DetailsTableItem(
              label: 'Transaction Fee',
              displayValue:
                  bitcoinUnit == BitcoinUnit.sats
                      ? FormatAmount.sats(
                        walletTransaction.feeSat,
                      ).toUpperCase()
                      : FormatAmount.btc(
                        ConvertAmount.satsToBtc(walletTransaction.feeSat),
                      ).toUpperCase(),
            ),
          DetailsTableItem(
            label: 'Status',
            displayValue: walletTransaction.status.displayName,
          ),
          if (walletTransaction.confirmationTime != null)
            DetailsTableItem(
              label: 'Confirmation time',
              displayValue: DateFormat(
                'MMM d, y, h:mm a',
              ).format(walletTransaction.confirmationTime!),
            ),
        ],
        // Swap info
        if (swap != null) ...[
          DetailsTableItem(
            label: 'Swap ID',
            displayValue: swap.id,
            copyValue: swap.id,
          ),
          if (counterpartWalletLabel != null &&
              counterpartWalletLabel.isNotEmpty)
            DetailsTableItem(
              label: tx.isOutgoing ? 'To wallet' : 'From wallet',
              displayValue: counterpartWalletLabel,
            ),
          if (swapCounterpartTransaction != null)
            DetailsTableItem(
              label:
                  swapCounterpartTransaction.isBitcoin
                      ? 'Bitcoin transaction ID'
                      : 'Liquid transaction ID',
              displayValue: abbreviatedSwapCounterpartTransactionTxId,
              copyValue: swapCounterpartTransaction.txId,
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
              expandableChild: Column(
                children: [
                  const Gap(4),

                  _feeRow(
                    context,
                    'Network Fee',
                    swap.fees!.lockupFee! + swap.fees!.claimFee!,
                  ),

                  _feeRow(context, 'Boltz Swap Fee', swap.fees?.boltzFee ?? 0),
                  const Gap(4),
                ],
              ),
            ),
          DetailsTableItem(
            label: 'Swap status',
            displayValue: swap.status.displayName,
            expandableChild: BBText(
              swap.getDisplayMessage(),
              style: context.font.bodySmall?.copyWith(
                color: context.colour.secondary,
              ),
              maxLines: 5,
            ),
          ),
          if (swap.completionTime != null)
            DetailsTableItem(
              label: 'Swap time received',
              displayValue: DateFormat(
                'MMM d, y, h:mm a',
              ).format(swap.completionTime!),
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

Widget _feeRow(BuildContext context, String label, int amt) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        BBText(
          label,
          style: context.font.bodySmall,
          color: context.colour.surfaceContainer,
        ),
        const Spacer(),
        CurrencyText(
          amt,
          showFiat: false,
          style: context.font.bodySmall,
          color: context.colour.surfaceContainer,
        ),
      ],
    ),
  );
}
