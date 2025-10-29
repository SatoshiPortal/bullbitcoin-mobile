import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/router.dart';
import 'package:bb_mobile/features/ark/ui/ark_balance_detail_widget.dart';
import 'package:bb_mobile/features/ark/ui/settle_bottom_sheet.dart';
import 'package:bb_mobile/features/ark/ui/transaction_history_widget.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ArkWalletDetailPage extends StatelessWidget {
  const ArkWalletDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ArkCubit>();
    final state = context.watch<ArkCubit>().state;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.goNamed(WalletRoute.walletHome.name),
        ),
        title: Text('Ark Instant Payments', style: context.font.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.settings),
            onPressed: () => context.pushNamed(ArkRoute.arkAbout.name),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                onRefresh: () async => await cubit.load(),
                child: SingleChildScrollView(
                  // Needed to allow pull-to-refresh even if content is too short
                  //  to be scrollable
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 160.0),
                  child: Column(
                    children: [
                      ArkBalanceDetailWidget(arkBalance: state.arkBalance),
                      if (state.isLoading)
                        LinearProgressIndicator(
                          backgroundColor: context.colour.surface,
                          color: context.colour.primary,
                        ),
                      const Gap(16.0),
                      TransactionHistoryWidget(
                        transactions: state.transactions,
                        isLoading: state.isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      /*final unsettledCount =
                          state.transactions
                              .whereType<ark_wallet.Transaction_Redeem>()
                              .where((tx) => !tx.isSettled)
                              .length;

                      if (unsettledCount == 0) {
                        return const SizedBox.shrink();
                      }*/

                      return Padding(
                        padding: const EdgeInsets.all(13.0),
                        child: BBButton.big(
                          label: 'Settle transactions',
                          onPressed:
                              () => SettleBottomSheet.show(context, cubit),
                          bgColor: context.colour.primary,
                          textColor: context.colour.onPrimary,
                        ),
                      );
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.only(
                      left: 13.0,
                      right: 13.0,
                      bottom: 40.0,
                    ),
                    child: ArkWalletBottomButtons(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArkWalletBottomButtons extends StatelessWidget {
  const ArkWalletBottomButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BBButton.big(
            iconData: Icons.arrow_downward,
            label: 'Receive',
            iconFirst: true,
            onPressed: () {
              context.pushNamed(ArkRoute.arkReceive.name);
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
          ),
        ),
        const Gap(4),
        Expanded(
          child: BBButton.big(
            iconData: Icons.crop_free,
            label: 'Send',
            iconFirst: true,
            onPressed: () {
              context.pushNamed(ArkRoute.arkSendRecipient.name);
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
            disabled: false,
          ),
        ),
      ],
    );
  }
}
