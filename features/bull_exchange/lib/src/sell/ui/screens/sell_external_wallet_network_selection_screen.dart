import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:bull_exchange/src/sell/domain/sell_payin_source.dart';
import 'package:bull_exchange/src/sell/ui/sell_router.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_exchange/src/sell/presentation/sell_bloc.dart';
import 'package:bull_exchange/src/sell/presentation/sell_failure_l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullScrollableColumn, Gap, BullTypographyX;

class SellExternalWalletNetworkSelectionScreen extends StatelessWidget {
  const SellExternalWalletNetworkSelectionScreen({super.key});

  void _selectNetwork(BuildContext context, BtcNetwork network) {
    context.pushNamed(
      SellRoute.sellPayout.name,
      extra: SellPayinSource.external(network),
    );
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
                    style: context.bullType.caption.copyWith(
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
                        : () => _selectNetwork(context, BtcNetwork.bitcoin),
                  ),
                  const Gap(24.0),
                  ListTile(
                    tileColor: context.appColors.onSecondary,
                    shape: const Border(),
                    title: Text(context.loc.sellLightningNetwork),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: isCreatingSellOrder
                        ? null
                        : () => _selectNetwork(context, BtcNetwork.lightning),
                  ),
                  const Gap(24.0),
                  ListTile(
                    tileColor: context.appColors.onSecondary,
                    shape: const Border(),
                    title: Text(context.loc.sellLiquidNetwork),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: isCreatingSellOrder
                        ? null
                        : () => _selectNetwork(context, BtcNetwork.liquid),
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
        style: context.bullType.body.copyWith(color: context.appColors.error),
        textAlign: TextAlign.center,
      ),
    );
  }
}
