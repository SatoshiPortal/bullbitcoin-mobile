import 'package:swaps/swaps.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        context.goNamed(WalletRoute.walletHome.name);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.loc.swapInternalTransferTitle),
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
                      if (swap?.status == SwapStatus.pending ||
                          swap?.status == SwapStatus.paid) ...[
                        const BullLoader.large(),
                        const Gap(8),
                        Text(
                          context.loc.swapTransferPendingTitle,
                          style: context.bullType.subtitle
                              .copyWith(fontWeight: FontWeight.w700)
                              .copyWith(color: context.appColors.secondary),
                        ),
                        const Gap(8),
                        Text(
                          context.loc.swapTransferPendingMessage,
                          style: context.bullType.body.copyWith(
                            color: context.appColors.secondary,
                          ),
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ],
                      if (swap?.status == SwapStatus.completed &&
                          swap?.refundTxid == null) ...[
                        Text(
                          context.loc.swapTransferCompletedTitle,
                          style: context.bullType.subtitle
                              .copyWith(fontWeight: FontWeight.w700)
                              .copyWith(color: context.appColors.secondary),
                        ),
                        const Gap(8),
                        Text(
                          context.loc.swapTransferCompletedMessage,
                          style: context.bullType.body.copyWith(
                            color: context.appColors.secondary,
                          ),
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ],
                      if (swap?.status == SwapStatus.refundable) ...[
                        Text(
                          context.loc.swapTransferRefundInProgressTitle,
                          style: context.bullType.subtitle
                              .copyWith(fontWeight: FontWeight.w700)
                              .copyWith(color: context.appColors.secondary),
                        ),
                        const Gap(8),
                        Text(
                          context.loc.swapTransferRefundInProgressMessage,
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
                          context.loc.swapTransferRefundedTitle,
                          style: context.bullType.subtitle
                              .copyWith(fontWeight: FontWeight.w700)
                              .copyWith(color: context.appColors.secondary),
                        ),
                        const Gap(8),
                        Text(
                          context.loc.swapTransferRefundedMessage,
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
                          swap?.status == SwapStatus.failed
                              ? context.loc.transactionStatusSwapFailed
                              : context.loc.transactionStatusSwapExpired,
                          style: context.bullType.subtitle
                              .copyWith(fontWeight: FontWeight.w700)
                              .copyWith(color: context.appColors.error),
                        ),
                        const Gap(8),
                        Text(
                          swap?.status == SwapStatus.failed
                              ? context.loc.transactionSwapDescChainFailed
                              : context.loc.transactionSwapDescChainExpired,
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
                if (orderSwap?.order?.requiresManualReview == true) ...[
                  OrderSwapUnderReviewCard(orderSwap: orderSwap!),
                  const Gap(16),
                ],
                if (!(swap?.status.isTerminal ?? false)) ...[
                  BullInfoCard(
                    description: context.loc.swapDoNotUninstallWarning,
                    tagColor: context.appColors.tertiary,
                    bgColor: context.appColors.warningContainer,
                    boldDescription: true,
                  ),
                  const Gap(12),
                  BullInfoCard(
                    description: context.loc.transactionSwapOpenWithin24h,
                    tagColor: context.appColors.tertiary,
                    bgColor: context.appColors.warningContainer,
                    boldDescription: true,
                  ),
                  const Gap(16),
                ],
                BullButton.secondary(
                  label: context.loc.swapGoHomeButton,
                  onPressed: () => context.goNamed(WalletRoute.walletHome.name),
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
