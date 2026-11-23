import 'package:primitives/primitives.dart' show BitcoinUnit, ConvertAmount;
import 'package:bb_mobile/features/coins/domain/wallet_utxo.dart';
import 'package:bb_mobile/features/coins/public/wallet_coin_selection.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
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
              : <WalletUtxo>[],
        )
        .where((u) => !u.isFrozen)
        .toList();

    final selectedUtxos = context.select(
      (PayBloc bloc) => bloc.state is PayPaymentState
          ? (bloc.state as PayPaymentState).selectedUtxos
          : <WalletUtxo>[],
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

    return walletCoinSelection(
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
