import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/widgets/badges/transaction_direction_badge.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/buy/ui/widgets/accelerate_transaction_list_tile.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/pay/ui/widgets/sinpe_receipt_bottom_sheet.dart';
import 'package:bb_mobile/features/replace_by_fee/router.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/models/transaction_detail_view.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/transaction_detail_view_builder.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/transaction_section_contributor.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/sender_broadcast_payjoin_original_tx_button.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_callout_card.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_details_amount.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_details_status_label.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_details_table.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/labels/ui/label_entry_bottom_sheet.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final returnHome =
        GoRouterState.of(context).uri.queryParameters['returnHome'] == 'true';
    final returnToExchange =
        GoRouterState.of(context).uri.queryParameters['returnToExchange'] ==
        'true';

    final state = context.watch<TransactionDetailsCubit>().state;
    final isLoading = state.isLoading;
    final tx = state.transaction;
    final wallet = state.wallet;
    final isPayjoinCompleted =
        state.payjoin?.status == PayjoinStatus.completed;
    final isBroadcastingPayjoinOriginalTx =
        state.isBroadcastingPayjoinOriginalTx;

    final walletTransaction = tx?.walletTransaction;
    final swap = tx?.swap;
    final isOutgoing = tx?.isOutgoing;
    final isOngoingSwap = tx?.isOngoingSwap;
    final isChainSwap = swap?.isChainSwap ?? false;

    final TransactionDetailView? view = (!isLoading && tx != null)
        ? locator<TransactionDetailViewBuilder>().build(
            tx,
            TxPresentDeps(
              loc: context.loc,
              wallet: wallet,
              counterpartWallet: state.counterpartWallet,
              walletLabel: wallet?.displayLabel(context) ?? '',
              counterpartWalletLabel:
                  state.counterpartWallet?.displayLabel(context) ?? '',
              swapCounterpartTxId: state.swapCounterpartTxId,
              amountSent: state.getAmountSent(),
              amountReceived: state.getAmountReceived(),
            ),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: isOngoingSwap == true
              ? (isChainSwap
                    ? context.loc.transactionDetailTransferProgress
                    : context.loc.transactionDetailSwapProgress)
              : context.loc.transactionDetailTitle,
          actionIcon: Icons.close,
          onAction: () {
            if (returnToExchange) {
              context.goNamed(ExchangeRoute.exchangeHome.name);
            } else if (returnHome) {
              context.goNamed(WalletRoute.walletHome.name);
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(WalletRoute.walletHome.name);
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3.0),
          child: FadingLinearProgress(
            trigger: isBroadcastingPayjoinOriginalTx,
            backgroundColor: context.appColors.onPrimary,
            foregroundColor: context.appColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: [
                if (view == null)
                  const LoadingBoxContent(height: 72, width: 72)
                else
                  TransactionDirectionBadge(
                    isIncoming: view.header.isIncoming,
                    isSwap: view.header.isTransfer,
                  ),
                const Gap(24),
                if (view == null)
                  const LoadingLineContent(width: 150)
                else
                  TransactionDetailsStatusLabel(header: view.header),
                if (view == null)
                  const LoadingLineContent(
                    height: 24,
                    width: 200,
                    padding: EdgeInsets.zero,
                  )
                else
                  TransactionDetailsAmount(amount: view.header.amount),
                const Gap(16),
                if (view != null)
                  for (final callout in view.callouts) ...[
                    TransactionCalloutCard(callout: callout),
                    const Gap(16),
                  ],
                if (tx?.isOrder == true &&
                    tx?.isBuyOrder == true &&
                    tx?.order != null &&
                    (tx!.order! as BuyOrder).bitcoinAddress != null &&
                    tx.order!.sentAt == null) ...[
                  AccelerateTransactionListTile(
                    orderId: tx.order!.orderId,
                    onTap: () {
                      context.pushNamed(
                        BuyRoute.buyAccelerate.name,
                        pathParameters: {'orderId': tx.order!.orderId},
                      );
                    },
                  ),
                  const Gap(16),
                ],
                if (view == null)
                  const LoadingBoxContent(height: 400)
                else
                  TransactionDetailsTable(view: view),
                if (tx?.order is FiatPaymentOrder &&
                    (tx!.order! as FiatPaymentOrder).payoutMethod ==
                        OrderPaymentMethod.sinpe &&
                    (tx.order! as FiatPaymentOrder).payoutCurrency ==
                        'CRC') ...[
                  const Gap(16),
                  BBButton.big(
                    label: context.loc.payViewReceipt,
                    onPressed: () {
                      showSinpeReceiptBottomSheet(
                        context,
                        tx.order! as FiatPaymentOrder,
                      );
                    },
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                ],
                const Gap(16),
                if (tx?.isOngoingPayjoinSender == true &&
                    !isPayjoinCompleted) ...[
                  const SenderBroadcastPayjoinOriginalTxButton(),
                  const Gap(24),
                ],
                if (view == null)
                  const LoadingLineContent(height: 40)
                else
                  BBButton.big(
                    label: context.loc.transactionDetailAddNote,
                    disabled:
                        !(walletTransaction != null &&
                            walletTransaction.labels.length < 10),
                    onPressed: () async {
                      if (walletTransaction == null ||
                          walletTransaction.labels.length >= 10) {
                        log.warning(
                          'A transaction can have up to 10 labels, current length: ${walletTransaction?.labels.length}',
                        );
                        return;
                      }
                      final cubit = context.read<TransactionDetailsCubit>();
                      final saved = await LabelEntryBottomSheet.label(
                        context,
                        title: context.loc.transactionNoteAddTitle,
                        suggestionsFuture: cubit.fetchDistinctLabels(),
                        hint: context.loc.transactionNoteHint,
                      );
                      if (saved == null || !context.mounted) return;
                      cubit.saveTransactionLabel(
                        NewLabel.tx(
                          transactionId: walletTransaction.txId,
                          label: saved,
                        ),
                      );
                    },
                    bgColor: context.appColors.transparent,
                    textColor: context.appColors.onSurface,
                    outlined: true,
                    borderColor: context.appColors.onSurface,
                  ),
                const Gap(16),
                if (isOutgoing == true &&
                    walletTransaction?.isConfirmed == false &&
                    walletTransaction?.isRbf == true &&
                    walletTransaction?.isBitcoin == true &&
                    wallet?.signsLocally == true &&
                    tx?.txId != null &&
                    swap == null)
                  BBButton.big(
                    label: context.loc.transactionDetailAccelerate,
                    onPressed: () {
                      context.pushNamed(
                        ReplaceByFeeRoute.replaceByFeeFlow.name,
                        extra: walletTransaction,
                      );
                    },
                    bgColor: context.appColors.onSurface,
                    textColor: context.appColors.surface,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
