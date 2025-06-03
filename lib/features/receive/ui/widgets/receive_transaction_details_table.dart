import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/mempool_url.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/ui/components/tables/details_table.dart';
import 'package:bb_mobile/ui/components/tables/details_table_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ReceiveTransactionDetailsTable extends StatelessWidget {
  const ReceiveTransactionDetailsTable({super.key});

  @override
  Widget build(BuildContext context) {
    // The tx state can still change from pending to confirmed, so watch the state
    final tx = context.select((ReceiveBloc bloc) => bloc.state.tx);
    final receiveType = context.select((ReceiveBloc bloc) => bloc.state.type);
    final amountSat =
        tx?.amountSat ??
        context.select((ReceiveBloc bloc) => bloc.state.confirmedAmountSat) ??
        0;
    final wallet = context.select((ReceiveBloc bloc) => bloc.state.wallet);
    final swap = context.select((ReceiveBloc bloc) => bloc.state.lightningSwap);
    final note = context.select((ReceiveBloc bloc) => bloc.state.note);
    final address = context.select((ReceiveBloc bloc) => bloc.state.address);
    final txId = context.select((ReceiveBloc bloc) => bloc.state.txId);
    final abbreviatedAddress = context.select(
      (ReceiveBloc bloc) => bloc.state.abbreviatedAddress,
    );
    final abbreviatedTxId = context.select(
      (ReceiveBloc bloc) => bloc.state.abbreviatedTxId,
    );
    final bitcoinUnit = context.select(
      (ReceiveBloc bloc) => bloc.state.bitcoinUnit,
    );
    final totalSwapFeesSat =
        (swap?.fees?.claimFee ?? 0) +
        (swap?.fees?.boltzFee ?? 0) +
        (swap?.fees?.lockupFee ?? 0);

    return DetailsTable(
      items: [
        DetailsTableItem(
          label: 'Amount received',
          displayValue:
              (bitcoinUnit == BitcoinUnit.sats
                      ? FormatAmount.sats(amountSat - totalSwapFeesSat)
                      : FormatAmount.btc(
                        ConvertAmount.satsToBtc(amountSat - totalSwapFeesSat),
                      ))
                  .toUpperCase(),
        ),
        if (swap != null && swap.fees != null)
          DetailsTableItem(
            label: 'Total Swap fees',
            displayValue:
                (bitcoinUnit == BitcoinUnit.sats
                        ? FormatAmount.sats(totalSwapFeesSat)
                        : FormatAmount.btc(
                          ConvertAmount.satsToBtc(totalSwapFeesSat),
                        ))
                    .toUpperCase(),
          ),
        if (receiveType == ReceiveType.lightning) ...[
          DetailsTableItem(
            label: 'Wallet',
            displayValue:
                wallet!.isLiquid ? 'Instant Payments' : 'Secure Bitcoin',
          ),
          if (receiveType == ReceiveType.lightning)
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
              if (swap.receiveTxid != null)
                DetailsTableItem(
                  label: 'Transaction Id',
                  displayValue: swap.abbreviatedReceiveTxid, // TODO: format
                  copyValue: swap.receiveTxid,
                  displayWidget:
                      swap.receiveTxid == null
                          ? null
                          : GestureDetector(
                            onTap: () async {
                              final url =
                                  wallet.isLiquid
                                      ? MempoolUrl.liquidTxidUrl(
                                        swap.receiveAddress ?? '',
                                      )
                                      : MempoolUrl.bitcoinTxidUrl(
                                        swap.receiveTxid!,
                                      );
                              await launchUrl(Uri.parse(url));
                            },
                            child: Text(
                              swap.abbreviatedReceiveTxid,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                ),
              DetailsTableItem(
                label: 'Lightning invoice',
                displayValue: swap.abbreviatedInvoice,
                copyValue: swap.invoice,
              ),
              /*DetailsTableItem(
                          label: 'Payment preimage',
                          displayValue: swap.preimage ?? '',
                        ),*/
            ],
        ] else ...[
          DetailsTableItem(
            label: 'Status',
            displayValue: tx?.status.name ?? '',
          ),
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
            displayWidget:
                txId.isEmpty
                    ? null
                    : GestureDetector(
                      onTap: () async {
                        final url =
                            wallet!.isLiquid
                                ? MempoolUrl.liquidTxidUrl(
                                  tx?.unblindedUrl ?? '',
                                )
                                : MempoolUrl.bitcoinTxidUrl(txId);
                        await launchUrl(Uri.parse(url));
                      },
                      child: Text(
                        abbreviatedTxId,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
          ),
        ],
        if (note.isNotEmpty)
          DetailsTableItem(label: 'Note', displayValue: note),
      ],
    );
  }
}
