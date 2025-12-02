import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
      appBar: AppBar(title: Text(context.loc.paySelectNetwork)),
      body: SafeArea(
        child: Column(
          children: [
            FadingLinearProgress(
              height: 3,
              trigger: isCreatingPayOrder,
              backgroundColor: context.colorScheme.onPrimary,
              foregroundColor: context.colorScheme.primary,
            ),
            Expanded(
              child: ScrollableColumn(
                children: [
                  const Gap(24.0),
                  Text(
                    context.loc.payHowToPayInvoice,
                    style: context.font.labelMedium?.copyWith(
                      color: Colors.black,
                    ),
                  ),
                  const Gap(24.0),
                  ListTile(
                    tileColor: context.colorScheme.onPrimary,
                    shape: const Border(),
                    title: Text(context.loc.payBitcoinOnchain),
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
                    tileColor: context.colorScheme.onPrimary,
                    shape: const Border(),
                    title: Text(context.loc.payLightningNetwork),
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
                    tileColor: context.colorScheme.onPrimary,
                    shape: const Border(),
                    title: Text(context.loc.payLiquidNetwork),
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
          context.loc.payAboveMaxAmount,
          style: context.font.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        BelowMinAmountPayError _ => Text(
          context.loc.payBelowMinAmount,
          style: context.font.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        UnauthenticatedPayError _ => Text(
          context.loc.payNotAuthenticated,
          style: context.font.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        OrderNotFoundPayError _ => Text(
          context.loc.payOrderNotFound,
          style: context.font.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        OrderAlreadyConfirmedPayError _ => Text(
          context.loc.payOrderAlreadyConfirmed,
          style: context.font.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        UnexpectedPayError _ => Text(
          payError.message,
          style: context.font.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
