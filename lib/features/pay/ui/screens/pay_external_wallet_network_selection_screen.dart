import 'package:bb_mobile/core_deprecated/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core_deprecated/widgets/scrollable_column.dart';
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
              backgroundColor: context.appColors.onPrimary,
              foregroundColor: context.appColors.primary,
            ),
            Expanded(
              child: ScrollableColumn(
                children: [
                  const Gap(24.0),
                  Text(
                    context.loc.payHowToPayInvoice,
                    style: context.font.labelMedium?.copyWith(
                      color: context.appColors.text,
                    ),
                  ),
                  const Gap(24.0),
                  ListTile(
                    tileColor: context.appColors.onPrimary,
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
                    tileColor: context.appColors.onPrimary,
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
                    tileColor: context.appColors.onPrimary,
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

    if (payError == null) return const SizedBox.shrink();

    return Center(
      child: Text(
        payError.toTranslated(context),
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.error,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
