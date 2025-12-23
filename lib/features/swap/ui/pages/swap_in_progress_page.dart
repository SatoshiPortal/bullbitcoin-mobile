import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

class SwapInProgressPage extends StatelessWidget {
  const SwapInProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final swap = context.select((TransferBloc bloc) => bloc.state.swap);

    return PopScope(
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
                        Gif(
                          autostart: Autostart.loop,
                          height: 123,
                          image: AssetImage(
                            Assets.animations.cubesLoading.path,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          context.loc.swapTransferPendingTitle,
                          style: context.font.headlineLarge,
                        ),
                        const Gap(8),
                        Text(
                          context.loc.swapTransferPendingMessage,
                          style: context.font.bodyMedium,
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ],
                      if (swap?.status == SwapStatus.completed &&
                          swap?.refundTxid == null) ...[
                        Text(
                          context.loc.swapTransferCompletedTitle,
                          style: context.font.headlineLarge,
                        ),
                        const Gap(8),
                        Text(
                          context.loc.swapTransferCompletedMessage,
                          style: context.font.bodyMedium,
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ],
                      if (swap?.status == SwapStatus.refundable) ...[
                        Text(
                          context.loc.swapTransferRefundInProgressTitle,
                          style: context.font.headlineLarge,
                        ),
                        const Gap(8),
                        Text(
                          context.loc.swapTransferRefundInProgressMessage,
                          style: context.font.bodyMedium,
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ],
                      if (swap?.status == SwapStatus.completed &&
                          swap?.refundTxid != null) ...[
                        Text(
                          context.loc.swapTransferRefundedTitle,
                          style: context.font.headlineLarge,
                        ),
                        const Gap(8),
                        Text(
                          context.loc.swapTransferRefundedMessage,
                          style: context.font.bodyMedium,
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                if (swap?.status != SwapStatus.completed) ...[
                  InfoCard(
                    description: context.loc.swapDoNotUninstallWarning,
                    tagColor: context.appColors.tertiary,
                    bgColor: context.appColors.warningContainer,
                    boldDescription: true,
                  ),
                  const Gap(16),
                ],
                BBButton.big(
                  label: context.loc.swapGoHomeButton,
                  onPressed: () => context.goNamed(WalletRoute.walletHome.name),
                  bgColor: context.appColors.secondary,
                  textColor: context.appColors.onSecondary,
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
