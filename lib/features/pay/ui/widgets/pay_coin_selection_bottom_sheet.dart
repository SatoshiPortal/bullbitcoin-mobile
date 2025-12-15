import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core_deprecated/utils/amount_conversions.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core_deprecated/widgets/coin_selection_bottom_sheet.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PayCoinSelectionBottomSheet extends StatelessWidget {
  const PayCoinSelectionBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final utxos = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState
              ? (bloc.state as PayPaymentState).utxos
              : <WalletUtxo>[],
    );

    final selectedUtxos = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState
              ? (bloc.state as PayPaymentState).selectedUtxos
              : <WalletUtxo>[],
    );

    final exchangeRate = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState
              ? (bloc.state as PayPaymentState).exchangeRateEstimate
              : 0.0,
    );

    final fiatCurrency = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState
              ? (bloc.state as PayPaymentState).currency.code
              : 'CAD',
    );

    final payinAmountSat = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState
              ? ConvertAmount.btcToSats(
                (bloc.state as PayPaymentState).payOrder.payinAmount,
              )
              : 0,
    );

    return CommonCoinSelectionBottomSheet(
      bitcoinUnit: BitcoinUnit.btc, // Pay always uses BTC
      exchangeRate: exchangeRate ?? 0.0,
      fiatCurrency: fiatCurrency,
      utxos: utxos,
      selectedUtxos: selectedUtxos,
      amountToSendSat: payinAmountSat,
      onUtxoSelected: (utxo) {
        context.read<PayBloc>().add(PayEvent.utxoSelected(utxo: utxo));
      },
    );
  }
}
