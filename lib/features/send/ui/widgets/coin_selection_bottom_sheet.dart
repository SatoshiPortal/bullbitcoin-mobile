import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/ui/widgets/coin_select_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
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
    // This used to be `selectedUtxoTotalSat > amountToSendSat`, which left the fee out: 2 020 sats picked for a 2 000 sat send read as sufficient although the transaction needed ~2 500, so Done stayed enabled and BDK made up the difference from a coin the user never picked.
    //
    // The fee can't be recomputed here. It moves with the input count, so amount + fee only settles once a PSBT exists, and the `absoluteFees` contract in send_state.dart forbids substituting local `rate × vsize` arithmetic. The gate is therefore the builder's own verdict: `utxoSelected` rebuilds on every tap, `createTransaction` clears the fee and the failure up front, and only a completed build puts a real fee back. So a fee means the current selection genuinely pays for the transaction, and no fee means it does not.
    //
    // An empty selection is "let BDK choose" and always passes; the wallet-wide insufficient-funds case belongs to the confirm screen, not here.
    final buildingTransaction = context.select(
      (SendCubit send) => send.state.buildingTransaction,
    );
    final hasBuiltFee = context.select(
      (SendCubit send) => send.state.absoluteFees != null,
    );
    final isAmountSufficient =
        selectedUtxos.isEmpty || (!buildingTransaction && hasBuiltFee);
    // Tied to the failure rather than to `!isAmountSufficient` so the warning
    // doesn't flash during the in-flight rebuild after every tap.
    final selectionIsShort = context.select(
      (SendCubit send) =>
          send.state.failure is SendInsufficientBalanceFailure ||
          send.state.failure is SendInsufficientFundsForFeesFailure,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: .min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: BBText(
                  context.loc.sendSelectAmount,
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
            '${context.loc.sendAmountRequested}$amountToSend',
            style: context.font.bodySmall,
          ),
          if (selectionIsShort) ...[
            const Gap(8),
            BBText(
              context.loc.sendSelectedUtxosInsufficient,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.error,
              ),
            ),
          ],
          const Gap(24),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, index) {
              final utxo = utxos[index];
              return CoinSelectTile(
                utxo: utxo,
                selected: selectedUtxos.any((u) => u.outpoint == utxo.outpoint),
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
          BBButton.big(
            label: context.loc.sendDone,
            onPressed: context.pop,
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
            disabled: !isAmountSufficient,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
