import 'package:bull_exchange/src/payin/payin_coin_selection.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, ConvertAmount;
import 'package:sync/sync.dart';
import 'package:bull_exchange/src/pay/presentation/pay_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PayCoinSelectionBottomSheet extends StatelessWidget {
  const PayCoinSelectionBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    // D7: frozen coins are never selectable for spending — hide them so the
    // sheet only ever offers spendable outputs (mirrors Send).
    final utxos = context
        .select(
          (PayBloc bloc) => bloc.state is PayPaymentState
              ? (bloc.state as PayPaymentState).utxos
              : <Coin>[],
        )
        .where((u) => !u.frozen)
        .toList();

    final selectedUtxos = context.select(
      (PayBloc bloc) => bloc.state is PayPaymentState
          ? (bloc.state as PayPaymentState).selectedUtxos
          : <Coin>[],
    );

    final exchangeRate = context.select(
      (PayBloc bloc) => bloc.state is PayPaymentState
          ? (bloc.state as PayPaymentState).exchangeRateEstimate
          : 0.0,
    );

    final fiatCurrency = context.select(
      (PayBloc bloc) => bloc.state is PayPaymentState
          ? (bloc.state as PayPaymentState).currency.code
          : 'CAD',
    );

    final payinAmountSat = context.select(
      (PayBloc bloc) => bloc.state is PayPaymentState
          ? ConvertAmount.btcToSats(
              (bloc.state as PayPaymentState).payOrder.payinAmount,
            )
          : 0,
    );

    return payinCoinSelection(
      context: context,
      bitcoinUnit: BitcoinUnit.btc,
      exchangeRate: exchangeRate,
      fiatCurrency: fiatCurrency,
      utxos: utxos,
      initialSelectedUtxos: selectedUtxos,
      amountToSendSat: payinAmountSat,
      onDone: (selectedUtxos) {
        context.read<PayBloc>().add(
          PayEvent.utxosSelected(utxos: selectedUtxos),
        );
      },
    );
  }
}
