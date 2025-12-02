import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
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
          title: const Text('Internal Transfer'),
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
                          'Transfer Pending',
                          style: context.font.headlineLarge,
                        ),
                        const Gap(8),
                        Text(
                          'The transfer is in progress. Bitcoin transactions can take a while to confirm. You can return home and wait.',
                          style: context.font.bodyMedium,
                          maxLines: 4,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (swap?.status == SwapStatus.completed &&
                          swap?.refundTxid == null) ...[
                        Text(
                          'Transfer completed',
                          style: context.font.headlineLarge,
                        ),
                        const Gap(8),
                        Text(
                          'Wow, you waited! The transfer has completed sucessfully.',
                          style: context.font.bodyMedium,
                          maxLines: 4,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (swap?.status == SwapStatus.refundable) ...[
                        Text(
                          'Transfer Refund In Progress',
                          style: context.font.headlineLarge,
                        ),
                        const Gap(8),
                        Text(
                          'There was an error with the transfer. Your refund is in progress.',
                          style: context.font.bodyMedium,
                          maxLines: 4,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (swap?.status == SwapStatus.completed &&
                          swap?.refundTxid != null) ...[
                        Text(
                          'Transfer Refunded',
                          style: context.font.headlineLarge,
                        ),
                        const Gap(8),
                        Text(
                          'The transfer has been sucessfully refunded.',
                          style: context.font.bodyMedium,
                          maxLines: 4,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                if (swap?.status != SwapStatus.completed) ...[
                  InfoCard(
                    description:
                        'Do not uninstall the app until the transfer completes!',
                    tagColor: context.colorScheme.tertiary,
                    bgColor: context.colorScheme.secondaryFixed,
                    boldDescription: true,
                  ),
                  const Gap(16),
                ],
                BBButton.big(
                  label: 'Go home',
                  onPressed: () => context.goNamed(WalletRoute.walletHome.name),
                  bgColor: context.colorScheme.secondary,
                  textColor: context.colorScheme.onSecondary,
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
