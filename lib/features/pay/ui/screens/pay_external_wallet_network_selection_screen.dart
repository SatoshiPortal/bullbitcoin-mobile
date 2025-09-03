import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class PayExternalWalletNetworkSelectionScreen extends StatelessWidget {
  const PayExternalWalletNetworkSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isCreatingPayOrder = context.select(
      (PayBloc bloc) =>
          bloc.state is PayWalletSelectionState &&
          (bloc.state as PayWalletSelectionState).isCreatingPayOrder,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Select Network')),
      body: SafeArea(
        child: Column(
          children: [
            FadingLinearProgress(
              height: 3,
              trigger: isCreatingPayOrder,
              backgroundColor: context.colour.onPrimary,
              foregroundColor: context.colour.primary,
            ),
            Expanded(
              child: ScrollableColumn(
                children: [
                  const Gap(24.0),
                  Text(
                    'How do you want to pay this invoice?',
                    style: context.font.labelMedium?.copyWith(
                      color: Colors.black,
                    ),
                  ),
                  const Gap(24.0),
                  ListTile(
                    tileColor: context.colour.onPrimary,
                    shape: const Border(),
                    title: const Text('Bitcoin on-chain'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        isCreatingPayOrder
                            ? null
                            : () => context.read<PayBloc>().add(
                              const PayEvent.externalWalletNetworkSelected(
                                network: OrderBitcoinNetwork.bitcoin,
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
                        isCreatingPayOrder
                            ? null
                            : () => context.read<PayBloc>().add(
                              const PayEvent.externalWalletNetworkSelected(
                                network: OrderBitcoinNetwork.lightning,
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
                        isCreatingPayOrder
                            ? null
                            : () => context.read<PayBloc>().add(
                              const PayEvent.externalWalletNetworkSelected(
                                network: OrderBitcoinNetwork.liquid,
                              ),
                            ),
                  ),
                  const Gap(24.0),
                  const _PayError(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayError extends StatelessWidget {
  const _PayError();

  @override
  Widget build(BuildContext context) {
    final payError = context.select(
      (PayBloc bloc) =>
          bloc.state is PayWalletSelectionState
              ? (bloc.state as PayWalletSelectionState).error
              : null,
    );

    return Center(
      child: switch (payError) {
        AboveMaxAmountPayError _ => Text(
          'You are trying to pay above the maximum amount that can be paid with this wallet.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        BelowMinAmountPayError _ => Text(
          'You are trying to pay below the minimum amount that can be paid with this wallet.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        UnauthenticatedPayError _ => Text(
          'You are not authenticated. Please log in to continue.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        OrderNotFoundPayError _ => Text(
          'The pay order was not found. Please try again.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        OrderAlreadyConfirmedPayError _ => Text(
          'This pay order has already been confirmed.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        UnexpectedPayError _ => Text(
          payError.message,
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
