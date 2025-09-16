import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/router.dart';
import 'package:bb_mobile/features/ark/ui/transaction_history_widget.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_detail_balance_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ArkWalletDetailPage extends StatelessWidget {
  const ArkWalletDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ArkCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: BBText(
          'Ark Instant Payments',
          style: context.font.headlineMedium,
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          WalletDetailBalanceCard(
            balanceSat: state.confirmedBalance + state.pendingBalance,
            isLiquid: false,
            signer: SignerEntity.local,
            hasSyncingIndicator: false,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13.0),
              child: TransactionHistoryWidget(transactions: state.transactions),
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
            onPressed: () {},
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
            disabled: false,
          ),
        ),
      ],
    );
  }
}
