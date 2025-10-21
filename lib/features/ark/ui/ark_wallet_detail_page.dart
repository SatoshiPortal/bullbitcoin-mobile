import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/router.dart';
import 'package:bb_mobile/features/ark/ui/ark_balance_detail_widget.dart';
import 'package:bb_mobile/features/ark/ui/settle_bottom_sheet.dart';
import 'package:bb_mobile/features/ark/ui/transaction_history_widget.dart';
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
        title: Text('Ark Instant Payments', style: context.font.headlineMedium),

        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.settings),
            onPressed: () => context.pushNamed(ArkRoute.arkAbout.name),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => await cubit.refresh(),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 160.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ArkBalanceDetailWidget(
                      confirmedBalance: state.confirmedBalance,
                      pendingBalance: state.pendingBalance,
                    ),

                    if (state.isLoading)
                      LinearProgressIndicator(
                        backgroundColor: context.colour.surface,
                        color: context.colour.primary,
                      ),

                    const Gap(16.0),
                    TransactionHistoryWidget(transactions: state.transactions),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      final unsettledCount =
                          state.transactions
                              .whereType<ark_wallet.Transaction_Redeem>()
                              .where((tx) => !tx.isSettled)
                              .length;

                      if (unsettledCount == 0) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.all(13.0),
                        child: BBButton.big(
                          label:
                              'Settle $unsettledCount ${unsettledCount == 1 ? 'transaction' : 'transactions'}',
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
            ],
          ),
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
              context.pushNamed(ArkRoute.arkSend.name);
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
