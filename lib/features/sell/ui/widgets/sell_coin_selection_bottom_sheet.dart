import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/widgets/coin_selection_bottom_sheet.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SellCoinSelectionBottomSheet extends StatelessWidget {
  const SellCoinSelectionBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bitcoinUnit = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState
              ? (bloc.state as SellPaymentState).bitcoinUnit
              : BitcoinUnit.btc,
    );

    final utxos = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState
              ? (bloc.state as SellPaymentState).utxos
              : <WalletUtxo>[],
    );

    final selectedUtxos = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState
              ? (bloc.state as SellPaymentState).selectedUtxos
              : <WalletUtxo>[],
    );

    final exchangeRate = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState
              ? (bloc.state as SellPaymentState).exchangeRateEstimate
              : 0.0,
    );

    final fiatCurrency = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState
              ? (bloc.state as SellPaymentState).fiatCurrency.code
              : 'CAD',
    );

    final payinAmountSat = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState
              ? ConvertAmount.btcToSats(
                (bloc.state as SellPaymentState).sellOrder.payinAmount,
              )
              : 0,
    );

    return CommonCoinSelectionBottomSheet(
      bitcoinUnit: bitcoinUnit,
      exchangeRate: exchangeRate ?? 0.0,
      fiatCurrency: fiatCurrency,
      utxos: utxos,
      selectedUtxos: selectedUtxos,
      amountToSendSat: payinAmountSat,
      onUtxoSelected: (utxo) {
        context.read<SellBloc>().add(SellEvent.utxoSelected(utxo: utxo));
      },
    );
  }
}
