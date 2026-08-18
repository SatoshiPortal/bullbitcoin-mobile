import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/ui/widgets/coin_select_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class CoinSelectionBottomSheet extends StatelessWidget {
  const CoinSelectionBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bitcoinUnit = context.select(
      (SendCubit send) => send.state.bitcoinUnit,
    );
    final exchangeRate = context.select(
      (SendCubit send) => send.state.exchangeRate,
    );
    final fiatCurrency = context.select(
      (SendCubit send) => send.state.fiatCurrencyCode,
    );
    // D7: frozen coins are never selectable for spending. Hide them so the
    // sheet only ever offers spendable outputs (isFrozen is already populated
    // by getWalletUtxos — no extra fetch needed here).
    final utxos = context
        .select((SendCubit send) => send.state.utxos)
        .where((u) => !u.isFrozen)
        .toList();
    final selectedUtxos = context.select(
      (SendCubit send) => send.state.selectedUtxos,
    );
    final selectedUtxoTotalSat = selectedUtxos.fold(
      0,
      (previousValue, element) => previousValue + element.amountSat.toInt(),
    );
    final selectedUtxoTotal = bitcoinUnit == BitcoinUnit.btc
        ? FormatAmount.btc(ConvertAmount.satsToBtc(selectedUtxoTotalSat))
        : FormatAmount.sats(selectedUtxoTotalSat);
    final amountToSendSat = context.select(
      (SendCubit send) => send.state.confirmedAmountSat ?? 0,
    );
    final amountToSend = bitcoinUnit == BitcoinUnit.btc
        ? FormatAmount.btc(ConvertAmount.satsToBtc(amountToSendSat))
        : FormatAmount.sats(amountToSendSat);
    final isAmountSufficient = selectedUtxoTotalSat > amountToSendSat;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: BullText(
                  context.loc.sendSelectAmount,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  iconSize: 24,
                  icon: const Icon(Icons.close),
                  onPressed: context.pop,
                ),
              ),
            ],
          ),
          const Gap(32),
          BullText(
            selectedUtxoTotal,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const Gap(8),
          BullText(
            '${context.loc.sendAmountRequested}$amountToSend',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!isAmountSufficient) ...[
            const Gap(8),
            BullText(
              context.loc.sendSelectedUtxosInsufficient,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.appColors.error),
            ),
          ],
          const Gap(24),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, index) {
              final utxo = utxos[index];
              return CoinSelectTile(
                utxo: utxo,
                selected: selectedUtxos.contains(utxo),
                onTap: () async =>
                    await context.read<SendCubit>().utxoSelected(utxo),
                exchangeRate: exchangeRate,
                bitcoinUnit: bitcoinUnit!,
                fiatCurrency: fiatCurrency,
              );
            },
            separatorBuilder: (_, _) => const Gap(24),
            itemCount: utxos.length,
            shrinkWrap: true,
          ),
          const Gap(24),
          BullButton.primary(
            label: context.loc.sendDone,
            onPressed: context.pop,
            disabled: !isAmountSufficient,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
