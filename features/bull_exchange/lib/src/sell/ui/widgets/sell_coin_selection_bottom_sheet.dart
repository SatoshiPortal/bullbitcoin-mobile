import 'package:bull_exchange/src/payin/payin_coin_selection.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, ConvertAmount;
import 'package:sync/sync.dart';
import 'package:bull_exchange/src/sell/presentation/sell_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SellCoinSelectionBottomSheet extends StatelessWidget {
  const SellCoinSelectionBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bitcoinUnit = context.select(
      (SellBloc bloc) => bloc.state is SellPaymentState
          ? (bloc.state as SellPaymentState).bitcoinUnit
          : BitcoinUnit.btc,
    );

    // D7: frozen coins are never selectable for spending — hide them so the
    // sheet only ever offers spendable outputs (mirrors Send).
    final utxos = context
        .select(
          (SellBloc bloc) => bloc.state is SellPaymentState
              ? (bloc.state as SellPaymentState).utxos
              : <Coin>[],
        )
        .where((u) => !u.frozen)
        .toList();

    final selectedUtxos = context.select(
      (SellBloc bloc) => bloc.state is SellPaymentState
          ? (bloc.state as SellPaymentState).selectedUtxos
          : <Coin>[],
    );

    final exchangeRate = context.select(
      (SellBloc bloc) => bloc.state is SellPaymentState
          ? (bloc.state as SellPaymentState).exchangeRateEstimate
          : 0.0,
    );

    final fiatCurrency = context.select(
      (SellBloc bloc) => bloc.state is SellPaymentState
          ? (bloc.state as SellPaymentState).fiatCurrency.code
          : 'CAD',
    );

    final payinAmountSat = context.select(
      (SellBloc bloc) => bloc.state is SellPaymentState
          ? ConvertAmount.btcToSats(
              (bloc.state as SellPaymentState).sellOrder.payinAmount,
            )
          : 0,
    );

    return payinCoinSelection(
      context: context,
      bitcoinUnit: bitcoinUnit,
      exchangeRate: exchangeRate,
      fiatCurrency: fiatCurrency,
      utxos: utxos,
      initialSelectedUtxos: selectedUtxos,
      amountToSendSat: payinAmountSat,
      onDone: (selectedUtxos) {
        context.read<SellBloc>().add(
          SellEvent.utxosSelected(utxos: selectedUtxos),
        );
      },
    );
  }
}
