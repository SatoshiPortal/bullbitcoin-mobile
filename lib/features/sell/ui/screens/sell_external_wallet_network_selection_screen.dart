import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
      appBar: AppBar(title: Text(context.loc.sellSelectNetwork)),
      body: SafeArea(
        child: Column(
          children: [
            FadingLinearProgress(
              height: 3,
              trigger: isCreatingSellOrder,
              backgroundColor: context.appColors.onPrimary,
              foregroundColor: context.appColors.primary,
            ),
            Expanded(
              child: ScrollableColumn(
                children: [
                  const Gap(24.0),
                  Text(
                    context.loc.sellHowToPayInvoice,
                    style: context.font.labelMedium?.copyWith(
                      color: context.appColors.text,
                    ),
                  ),
                  const Gap(24.0),
                  ListTile(
                    tileColor: context.appColors.onSecondary,
                    shape: const Border(),
                    title: Text(context.loc.sellBitcoinOnChain),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        isCreatingSellOrder
                            ? null
                            : () => context.read<SellBloc>().add(
                              const SellEvent.externalWalletNetworkSelected(
                                network: OrderBitcoinNetwork.bitcoin,
                              ),
                            ),
                  ),
                  const Gap(24.0),
                  ListTile(
                    tileColor: context.appColors.onSecondary,
                    shape: const Border(),
                    title: Text(context.loc.sellLightningNetwork),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        isCreatingSellOrder
                            ? null
                            : () => context.read<SellBloc>().add(
                              const SellEvent.externalWalletNetworkSelected(
                                network: OrderBitcoinNetwork.lightning,
                              ),
                            ),
                  ),
                  const Gap(24.0),
                  ListTile(
                    tileColor: context.appColors.onSecondary,
                    shape: const Border(),
                    title: Text(context.loc.sellLiquidNetwork),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        isCreatingSellOrder
                            ? null
                            : () => context.read<SellBloc>().add(
                              const SellEvent.externalWalletNetworkSelected(
                                network: OrderBitcoinNetwork.liquid,
                              ),
                            ),
                  ),
                  const Gap(24.0),
                  const _SellError(),
                ],
              ),
            ),
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

    if (sellError == null) return const SizedBox.shrink();

    return Center(
      child: Text(
        sellError.toTranslated(context),
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.error,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
