import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SellExternalWalletNetworkSelectionScreen extends StatelessWidget {
  const SellExternalWalletNetworkSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isCreatingSellOrder = context.select(
      (SellBloc bloc) =>
          bloc.state is SellWalletSelectionState &&
          (bloc.state as SellWalletSelectionState).isCreatingSellOrder,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Select Network')),
      body: SafeArea(
        child: ScrollableColumn(
          children: [
            const Gap(40.0),
            Text(
              'How do you want to pay this invoice?',
              style: context.font.labelMedium?.copyWith(color: Colors.black),
            ),
            const Gap(24.0),
            ListTile(
              tileColor: context.colour.onPrimary,
              shape: const Border(),
              title: const Text('Bitcoin on-chain'),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  isCreatingSellOrder
                      ? null
                      : () => context.read<SellBloc>().add(
                        const SellEvent.externalWalletNetworkSelected(
                          network: OrderPaymentMethod.bitcoin,
                        ),
                      ),
            ),
            const Gap(24.0),
            ListTile(
              tileColor: context.colour.onPrimary,
              shape: const Border(),
              title: const Text('Lightning Network'),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  isCreatingSellOrder
                      ? null
                      : () => context.read<SellBloc>().add(
                        const SellEvent.externalWalletNetworkSelected(
                          network: OrderPaymentMethod.lnInvoice,
                        ),
                      ),
            ),
            const Gap(24.0),
            ListTile(
              tileColor: context.colour.onPrimary,
              shape: const Border(),
              title: const Text('Liquid Network'),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  isCreatingSellOrder
                      ? null
                      : () => context.read<SellBloc>().add(
                        const SellEvent.externalWalletNetworkSelected(
                          network: OrderPaymentMethod.liquid,
                        ),
                      ),
            ),
            const Gap(24.0),
            if (isCreatingSellOrder) ...[
              FadingLinearProgress(
                height: 3,
                trigger: isCreatingSellOrder,
                backgroundColor: context.colour.onPrimary,
                foregroundColor: context.colour.primary,
              ),
              const Gap(16.0),
            ],
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
        _ => const SizedBox.shrink(),
      },
    );
  }
}
