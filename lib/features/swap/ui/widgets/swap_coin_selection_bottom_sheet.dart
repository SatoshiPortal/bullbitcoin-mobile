import 'package:bb_mobile/core/widgets/coin_selection_bottom_sheet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapCoinSelectionBottomSheet extends StatelessWidget {
  const SwapCoinSelectionBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final utxos = context.select(
      (TransferBloc bloc) => bloc.state.utxos ?? <WalletUtxo>[],
    );

    final selectedUtxos = context.select(
      (TransferBloc bloc) => bloc.state.selectedUtxos,
    );

    final exchangeRate = context.select(
      (TransferBloc bloc) => bloc.state.exchangeRate ?? 0.0,
    );

    final fiatCurrency = context.select(
      (TransferBloc bloc) => bloc.state.fiatCurrencyCode ?? 'CAD',
    );

    final bitcoinUnit = context.select(
      (TransferBloc bloc) => bloc.state.bitcoinUnit,
    );

    final amountToSendSat = context.select(
      (TransferBloc bloc) => bloc.state.confirmedAmountSat,
    );

    return CommonCoinSelectionBottomSheet(
      bitcoinUnit: bitcoinUnit,
      exchangeRate: exchangeRate,
      fiatCurrency: fiatCurrency,
      utxos: utxos,
      selectedUtxos: selectedUtxos,
      amountToSendSat: amountToSendSat,
      onUtxoSelected: (utxo) {
        context.read<TransferBloc>().add(
          TransferEvent.utxoSelected(utxo),
        );
      },
    );
  }
}

