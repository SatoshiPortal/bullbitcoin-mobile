import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/widgets/badges/transaction_direction_badge.dart';
import 'package:bb_mobile/core/widgets/bb_refresh_indicator.dart';
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
import 'package:bb_mobile/features/transactions/ui/widgets/sender_broadcast_payjoin_original_tx_button.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/order_swap_status_description.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/swap_progress_indicator.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/swap_status_description.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_details_amount.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_details_status_label.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_details_table.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/labels/ui/label_entry_bottom_sheet.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
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
    final isLoading = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.isLoading,
    );
    final hasLoadError = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.hasLoadError,
    );
    final tx = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.transaction,
    );
    final wallet = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.wallet,
    );
    // The single source of truth this button's visibility must agree with —
    // see Payjoin.canManuallyBroadcastOriginal's doc comment. Deriving both
    // from the same getter as the cubit's own guard means the button can
    // never be shown for a session where tapping it would just silently
    // no-op (observed live before this was unified: a stale-looking button
    // let a tap through that re-broadcast an already-completed session).
    final canManuallyBroadcastOriginal = context.select(
      (TransactionDetailsCubit bloc) =>
          bloc.state.payjoin?.canManuallyBroadcastOriginal ?? false,
    );
    final isBroadcastingPayjoinOriginalTx = context.select(
      (TransactionDetailsCubit bloc) =>
          bloc.state.isBroadcastingPayjoinOriginalTx,
    );

    final isOutgoing = tx?.isOutgoing;
    final isIncoming = tx?.isIncoming;
    final isOngoingSwap = tx?.isOngoingSwap;
    final isOrderType = tx?.isOrder == true;
    final walletTransaction = tx?.walletTransaction;
    final swap = tx?.swap;
    final orderSwap = tx?.orderSwap;
    final isChainSwap = tx?.isChainSwap ?? false;

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
        child: BBRefreshIndicator(
          onRefresh: () => context.read<TransactionDetailsCubit>().refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (hasLoadError)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _LoadErrorContent(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: Column(
                        children: [
                          if (isLoading)
                            const LoadingBoxContent(height: 72, width: 72)
                          else
                            TransactionDirectionBadge(
                              isIncoming: isIncoming ?? false,
                              isSwap: isChainSwap,
                            ),
                          const Gap(24),
                          if (isLoading)
                            const LoadingLineContent(width: 150)
                          else
                            const TransactionDetailsStatusLabel(),
                          if (isOngoingSwap == true && swap != null) ...[
                            const Gap(8),
                            SwapProgressIndicator(swap: swap),
                          ],
                          if (isLoading)
                            const LoadingLineContent(
                              height: 24,
                              width: 200,
                              padding: EdgeInsets.zero,
                            )
                          else
                            const TransactionDetailsAmount(),
                          const Gap(16),
                          if (isOngoingSwap == true && swap != null) ...[
                            SwapStatusDescription(swap: swap),
                            const Gap(16),
                          ],
                          if (isOngoingSwap == true && orderSwap != null) ...[
                            OrderSwapStatusDescription(orderSwap: orderSwap),
                            const Gap(16),
                          ],
                          if (isOrderType &&
                              tx?.isBuyOrder == true &&
                              tx?.order != null &&
                              (tx!.order! as BuyOrder).bitcoinAddress != null &&
                              tx.order!.sentAt == null) ...[
                            AccelerateTransactionListTile(
                              orderId: tx.order!.orderId,
                              onTap: () {
                                context.pushNamed(
                                  BuyRoute.buyAccelerate.name,
                                  pathParameters: {
                                    'orderId': tx.order!.orderId,
                                  },
                                );
                              },
                            ),
                            const Gap(16),
                          ],
                          if (isLoading)
                            const LoadingBoxContent(height: 400)
                          else
                            const TransactionDetailsTable(),
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
                              canManuallyBroadcastOriginal) ...[
                            const SenderBroadcastPayjoinOriginalTxButton(),
                            const Gap(24),
                          ],
                          if (isLoading)
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
                                final cubit = context
                                    .read<TransactionDetailsCubit>();
                                final saved = await LabelEntryBottomSheet.label(
                                  context,
                                  title: context.loc.transactionNoteAddTitle,
                                  suggestionsFuture: cubit
                                      .fetchDistinctLabels(),
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
                              tx?.isSwap != true)
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
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadErrorContent extends StatelessWidget {
  const _LoadErrorContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.loc.transactionDetailLoadError,
              textAlign: TextAlign.center,
              style: context.font.bodyMedium,
            ),
            const Gap(16),
            BBButton.small(
              label: context.loc.retry,
              onPressed: () =>
                  context.read<TransactionDetailsCubit>().refresh(),
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
