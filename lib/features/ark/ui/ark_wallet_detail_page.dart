import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/presentation/state.dart';
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
    final cubit = context.read<ArkCubit>();
    final state = context.watch<ArkCubit>().state;
    final hasBoardingTransaction = state.hasBoardingTransaction;

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
          if (hasBoardingTransaction)
            Padding(
              padding: const EdgeInsets.all(13.0),
              child: BBButton.big(
                label: 'Settle Boarding Transactions',
                onPressed: () => _showSettleTransactionModal(context, cubit),
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

void _showSettleTransactionModal(BuildContext context, ArkCubit cubit) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colour.onPrimary,
    builder: (BuildContext modalContext) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BBText(
              'Settle Boarding Transaction',
              style: modalContext.font.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const Gap(16),
            BBText(
              'Boarding transactions need to be settled to fund your Ark balance.',
              style: modalContext.font.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: BBButton.big(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(modalContext).pop(),
                    bgColor: modalContext.colour.surface,
                    textColor: modalContext.colour.onSurface,
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: BBButton.big(
                    label: 'Settle',
                    onPressed: () {
                      try {
                        cubit.settle();
                        Navigator.of(modalContext).pop();
                      } catch (_) {}
                    },
                    bgColor: modalContext.colour.primary,
                    textColor: modalContext.colour.onPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
