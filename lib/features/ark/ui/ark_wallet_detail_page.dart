import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/router.dart';
import 'package:bb_mobile/features/ark/ui/ark_balance_detail_widget.dart';
import 'package:bb_mobile/features/ark/ui/settle_bottom_sheet.dart';
import 'package:bb_mobile/features/ark/ui/transaction_history_widget.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
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
        flexibleSpace: TopBar(
          title: 'Ark Instant Payments',
          onBack: () => context.goNamed(WalletRoute.walletHome.name),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13.0),
              child: TransactionHistoryWidget(transactions: state.transactions),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(13.0),
            child: BBButton.small(
              label: 'Settle',
              onPressed: () => SettleBottomSheet.show(context, cubit),
              bgColor: context.colour.primary,
              textColor: context.colour.onPrimary,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 13.0, right: 13.0, bottom: 40.0),
            child: ArkWalletBottomButtons(),
          ),
        ],
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
