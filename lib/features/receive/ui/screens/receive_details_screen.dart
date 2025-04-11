import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_arrow_badge.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_transaction_details.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ReceiveDetailsScreen extends StatelessWidget {
  const ReceiveDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The tx state can still change from pending to confirmed, so watch the state
    final state = context.watch<ReceiveBloc>().state;
    final tx = state.tx;
    final receiveType = state.type;
    final amountSat = tx?.amountSat ?? state.confirmedAmountSat?.toInt() ?? 0;
    final wallet = state.wallet!;
    final swap = state.lightningSwap;
    final note = state.note;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation

        context.go(AppRoute.home.path);
      },
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: 'Receive',
            actionIcon: Icons.close,
            onAction: () {
              context.go(AppRoute.home.path);
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                children: [
                  const ReceiveArrowBadge(),
                  const Gap(24),
                  BBText(
                    'Payment received',
                    style: context.font.headlineLarge,
                  ),
                  const Gap(8),
                  BBText(
                    FormatAmount.sats(amountSat),
                    style: context.font.displaySmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(24),
                  ReceiveTransactionDetails(
                    items: [
                      ReceiveTransactionDetailsItem(
                        label: 'Amount received',
                        displayValue:
                            FormatAmount.sats(amountSat).toUpperCase(),
                      ),
                      if (receiveType == ReceiveType.lightning) ...[
                        ReceiveTransactionDetailsItem(
                          label: 'Wallet',
                          displayValue: wallet.isLiquid
                              ? 'Instant Payments'
                              : 'Secure Bitcoin',
                        ),
                        if (receiveType == ReceiveType.lightning)
                          if (swap != null) ...[
                            ReceiveTransactionDetailsItem(
                              label: 'Swap status',
                              displayValue: swap.status.name,
                            ),
                            ReceiveTransactionDetailsItem(
                              label: 'Swap ID',
                              displayValue: swap.id,
                              copyValue: swap.id,
                            ),
                            if (swap.completionTime != null)
                              ReceiveTransactionDetailsItem(
                                label: 'Time received',
                                displayValue: DateFormat('MMM d, y, h:mm a')
                                    .format(swap.completionTime!),
                              ),
                            if (swap.receiveTxid != null)
                              ReceiveTransactionDetailsItem(
                                label: 'Transaction Id',
                                displayValue:
                                    swap.abbreviatedReceiveTxid, // TODO: format
                                copyValue: swap.receiveTxid,
                              ),
                            ReceiveTransactionDetailsItem(
                              label: 'Lightning invoice',
                              displayValue: swap.abbreviatedInvoice,
                              copyValue: swap.invoice,
                            ),
                            /*ReceiveTransactionDetailsItem(
                          label: 'Payment preimage',
                          displayValue: swap.preimage ?? '',
                        ),*/
                          ]
                      ] else ...[
                        ReceiveTransactionDetailsItem(
                          label: 'Status',
                          displayValue: tx?.status.name ?? '',
                        ),
                        if (tx?.confirmationTime != null)
                          ReceiveTransactionDetailsItem(
                            label: 'Confirmation time',
                            displayValue: DateFormat('MMM d, y, h:mm a')
                                .format(tx!.confirmationTime!),
                          ),
                        ReceiveTransactionDetailsItem(
                          label: 'Address',
                          displayValue: state.abbreviatedAddress,
                          copyValue: state.address,
                        ),
                        ReceiveTransactionDetailsItem(
                          label: 'Transaction ID',
                          displayValue: state.abbreviatedTxId,
                          copyValue: state.txId,
                        ),
                      ],
                      if (note.isNotEmpty)
                        ReceiveTransactionDetailsItem(
                          label: 'Note',
                          displayValue: note,
                        ),
                    ],
                  ),
                  const Gap(62),
                  BBButton.big(
                    label: 'Edit label',
                    onPressed: () {},
                    bgColor: Colors.transparent,
                    textColor: theme.colorScheme.secondary,
                    outlined: true,
                    borderColor: theme.colorScheme.secondary,
                  ),
                  const Gap(16),
                  BBButton.big(
                    label: 'Done',
                    onPressed: () {
                      context.go(AppRoute.home.path);
                    },
                    bgColor: theme.colorScheme.secondary,
                    textColor: theme.colorScheme.onPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
        // child: AmountPage(),
      ),
    );
  }
}
