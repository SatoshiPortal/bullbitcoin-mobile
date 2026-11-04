import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/sell_payin_source_v2.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/features/sell/presentation/sell_bloc.dart';
import 'package:bb_mobile/features/sell/presentation/sell_failure_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullScrollableColumn, Gap;

class SellExternalWalletNetworkSelectionScreen extends StatelessWidget {
  const SellExternalWalletNetworkSelectionScreen({super.key});

  void _selectNetwork(BuildContext context, OrderBitcoinNetwork network) {
    if (context.read<SellBloc>().state.fiatCurrency == FiatCurrency.eur) {
      context.pushNamed(
        SellRoute.sellPayoutV2.name,
        extra: SellPayinSourceV2.external(network),
      );
    } else {
      context.read<SellBloc>().add(
        SellEvent.externalWalletNetworkSelected(network: network),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreatingSellOrder = context.select(
      (SellBloc bloc) => bloc.state is SellPreparingPaymentState,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.sellSelectNetwork)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BullScrollableColumn(
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
                    onTap: isCreatingSellOrder
                        ? null
                        : () => _selectNetwork(
                            context,
                            OrderBitcoinNetwork.bitcoin,
                          ),
                  ),
                  const Gap(24.0),
                  ListTile(
                    tileColor: context.appColors.onSecondary,
                    shape: const Border(),
                    title: Text(context.loc.sellLightningNetwork),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: isCreatingSellOrder
                        ? null
                        : () => _selectNetwork(
                            context,
                            OrderBitcoinNetwork.lightning,
                          ),
                  ),
                  const Gap(24.0),
                  ListTile(
                    tileColor: context.appColors.onSecondary,
                    shape: const Border(),
                    title: Text(context.loc.sellLiquidNetwork),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: isCreatingSellOrder
                        ? null
                        : () => _selectNetwork(
                            context,
                            OrderBitcoinNetwork.liquid,
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
    final SellFailure? sellError = context.select(
      (SellBloc bloc) => bloc.state is SellWalletSelectionState
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
