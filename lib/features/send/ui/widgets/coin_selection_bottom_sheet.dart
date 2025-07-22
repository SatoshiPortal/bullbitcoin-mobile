import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/ui/widgets/coin_select_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
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
    final utxos = context.select((SendCubit send) => send.state.utxos);
    final selectedUtxos = context.select(
      (SendCubit send) => send.state.selectedUtxos,
    );
    final selectedUtxoTotalSat = selectedUtxos.fold(
      0,
      (previousValue, element) => previousValue + element.amountSat.toInt(),
    );
    final selectedUtxoTotal =
        bitcoinUnit == BitcoinUnit.btc
            ? FormatAmount.btc(ConvertAmount.satsToBtc(selectedUtxoTotalSat))
            : FormatAmount.sats(selectedUtxoTotalSat);
    final amountToSendSat = context.select(
      (SendCubit send) => send.state.confirmedAmountSat ?? 0,
    );
    final amountToSend =
        bitcoinUnit == BitcoinUnit.btc
            ? FormatAmount.btc(ConvertAmount.satsToBtc(amountToSendSat))
            : FormatAmount.sats(amountToSendSat);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: BBText(
                  "Select amount",
                  style: context.font.headlineMedium,
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
          BBText(selectedUtxoTotal, style: context.font.displaySmall),
          const Gap(8),
          BBText(
            'Amount requested: $amountToSend',
            style: context.font.bodySmall,
          ),
          const Gap(24),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, index) {
              final utxo = utxos[index];
              return CoinSelectTile(
                utxo: utxo,
                selected: selectedUtxos.contains(utxo),
                onTap:
                    () async =>
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
          BBButton.big(
            label: "Done",
            onPressed: context.pop,
            bgColor: context.colour.secondary,
            textColor: context.colour.onSecondary,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
