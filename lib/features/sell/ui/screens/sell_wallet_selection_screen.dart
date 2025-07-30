import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SellWalletSelectionScreen extends StatelessWidget {
  const SellWalletSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isCreatingSellOrder = context.select(
      (SellBloc bloc) =>
          bloc.state is SellWalletSelectionState &&
          (bloc.state as SellWalletSelectionState).isCreatingSellOrder,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Select Wallet')),
      body: SafeArea(
        child: ScrollableColumn(
          children: [
            const Gap(40.0),
            Text(
              'Which wallet do you want to sell from?',
              style: context.font.labelMedium?.copyWith(color: Colors.black),
            ),
            const Gap(24.0),
            WalletCards(
              padding: EdgeInsets.zero,
              onTap:
                  isCreatingSellOrder
                      ? null
                      : (wallet) => context.read<SellBloc>().add(
                        SellEvent.walletSelected(wallet: wallet),
                      ),
            ),
            const Gap(24.0),
            ListTile(
              tileColor: context.colour.onPrimary,
              shape: const Border(),
              title: const Text('External wallet'),
              subtitle: const Text('Sell from another Bitcoin wallet'),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  isCreatingSellOrder
                      ? null
                      : () => context.pushNamed(
                        SellRoute.sellExternalWalletNetworkSelection.name,
                      ),
            ),
            const Gap(24.0),
            if (isCreatingSellOrder) const CircularProgressIndicator(),
            const _SellError(),
          ],
        ),
      ),
    );
  }
}

class _SellError extends StatelessWidget {
  const _SellError();

  @override
  Widget build(BuildContext context) {
    final sellError = context.select(
      (SellBloc bloc) =>
          bloc.state is SellWalletSelectionState
              ? (bloc.state as SellWalletSelectionState).error
              : null,
    );

    return Center(
      child: switch (sellError) {
        AboveMaxAmountSellError _ => Text(
          'You are trying to sell above the maximum amount that can be sold with this wallet.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        BelowMinAmountSellError _ => Text(
          'You are trying to sell below the minimum amount that can be sold with this wallet.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        InsufficientBalanceSellError _ => Text(
          'Insufficient balance in the selected wallet to complete this sell order.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
