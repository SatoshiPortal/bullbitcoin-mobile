import 'package:swap_feature/src/public/order_swap_under_review_card.dart';
import 'package:swaps/swaps.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:swap_feature/src/presentation/swap_failure_l10n.dart';
import 'package:transactions/payment_status.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullInfoCard, BullLoader, Gap, BullTypographyX;
import 'package:go_router/go_router.dart';

class SwapInProgressPage extends StatelessWidget {
  const SwapInProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final swap = context.select((TransferBloc bloc) => bloc.state.swap);
    final orderSwap = context.select(
      (TransferBloc bloc) => bloc.state.orderSwap,
    );
    final swapFailure = context.select(
      (TransferBloc bloc) => bloc.state.swapFailure,
    );
    final fundingTxId = context.select((TransferBloc bloc) => bloc.state.txId);
    final provisionalFailure =
        swap != null &&
        (swap.status == SwapStatus.failed ||
            swap.status == SwapStatus.expired) &&
        swapFundingMayHaveMoved(swap, orderSwap, fundingTxId: fundingTxId);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        context.go('/wallet');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.swapCopyForLocale.swapInternalTransferTitle),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      if (swapFailure != null) ...[
                        Text(
                          swapFailure.toTranslated(context),
                          style: context.bullType.body.copyWith(
                            color: context.appColors.error,
                          ),
                          textAlign: .center,
                        ),
                        const Gap(8),
                      ],
                      if (swap?.status == SwapStatus.pending ||
                          swap?.status == SwapStatus.paid ||
                          swap?.status == SwapStatus.claimable ||
                          swap?.status == SwapStatus.canCoop ||
                          (swap?.status == SwapStatus.completed &&
                              swap?.refundTxid == null &&
                              !(swap?.receiveTxid?.isNotEmpty ?? false))) ...[
                        const BullLoader.large(),
                        const Gap(8),
                        Text(
                          context.swapCopyForLocale.swapTransferPendingTitle,
                          style: context.bullType.subtitle
                              .copyWith(fontWeight: FontWeight.w700)
                              .copyWith(color: context.appColors.secondary),
                        ),
                        const Gap(8),
                        Text(
                          context.swapCopyForLocale.swapTransferPendingMessage,
                          style: context.bullType.body.copyWith(
                            color: context.appColors.secondary,
                          ),
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ],
                      if (swap?.status == SwapStatus.completed &&
                          swap?.refundTxid == null &&
                          (swap?.receiveTxid?.isNotEmpty ?? false)) ...[
                        Text(
                          context.swapCopyForLocale.swapTransferCompletedTitle,
                          style: context.bullType.subtitle
                              .copyWith(fontWeight: FontWeight.w700)
                              .copyWith(color: context.appColors.secondary),
                        ),
                        const Gap(8),
                        Text(
                          context
                              .swapCopyForLocale
                              .swapTransferCompletedMessage,
                          style: context.bullType.body.copyWith(
                            color: context.appColors.secondary,
                          ),
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ],
                      if (swap?.status == SwapStatus.refundable) ...[
                        Text(
                          context
                              .swapCopyForLocale
                              .swapTransferRefundInProgressTitle,
                          style: context.bullType.subtitle
                              .copyWith(fontWeight: FontWeight.w700)
                              .copyWith(color: context.appColors.secondary),
                        ),
                        const Gap(8),
                        Text(
                          context
                              .swapCopyForLocale
                              .swapTransferRefundInProgressMessage,
                          style: context.bullType.body.copyWith(
                            color: context.appColors.secondary,
                          ),
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ],
                      if (swap?.status == SwapStatus.refunded ||
                          (swap?.status == SwapStatus.completed &&
                              swap?.refundTxid != null)) ...[
                        Text(
                          context.swapCopyForLocale.swapTransferRefundedTitle,
                          style: context.bullType.subtitle
                              .copyWith(fontWeight: FontWeight.w700)
                              .copyWith(color: context.appColors.secondary),
                        ),
                        const Gap(8),
                        Text(
                          context.swapCopyForLocale.swapTransferRefundedMessage,
                          style: context.bullType.body.copyWith(
                            color: context.appColors.secondary,
                          ),
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ],
                      if (swap?.status == SwapStatus.failed ||
                          swap?.status == SwapStatus.expired) ...[
                        Text(
                          provisionalFailure
                              ? context
                                    .swapCopyForLocale
                                    .swapTransferPendingTitle
                              : swap?.status == SwapStatus.failed
                              ? context
                                    .swapCopyForLocale
                                    .transactionStatusSwapFailed
                              : context
                                    .swapCopyForLocale
                                    .transactionStatusSwapExpired,
                          style: context.bullType.subtitle
                              .copyWith(fontWeight: FontWeight.w700)
                              .copyWith(color: context.appColors.error),
                        ),
                        const Gap(8),
                        Text(
                          provisionalFailure
                              ? context
                                    .swapCopyForLocale
                                    .swapTransferPendingMessage
                              : swap?.status == SwapStatus.failed
                              ? context
                                    .swapCopyForLocale
                                    .transactionSwapDescChainFailed
                              : context
                                    .swapCopyForLocale
                                    .transactionSwapDescChainExpired,
                          style: context.bullType.body.copyWith(
                            color: context.appColors.secondary,
                          ),
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                if (orderSwap != null &&
                    orderSwap.order?.requiresManualReview == true) ...[
                  OrderSwapUnderReviewCard(orderSwap: orderSwap),
                  const Gap(16),
                ],
                if (!(swap?.status.isTerminal ?? false) ||
                    provisionalFailure) ...[
                  BullInfoCard(
                    description:
                        context.swapCopyForLocale.swapDoNotUninstallWarning,
                    tagColor: context.appColors.tertiary,
                    bgColor: context.appColors.warningContainer,
                    boldDescription: true,
                  ),
                  const Gap(12),
                  BullInfoCard(
                    description:
                        context.swapCopyForLocale.transactionSwapOpenWithin24h,
                    tagColor: context.appColors.tertiary,
                    bgColor: context.appColors.warningContainer,
                    boldDescription: true,
                  ),
                  const Gap(16),
                ],
                BullButton.secondary(
                  label: context.swapCopyForLocale.swapGoHomeButton,
                  onPressed: () => context.go('/wallet'),
                ),
                const Gap(32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
