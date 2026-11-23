import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:coins/coins.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import '../../swap_l10n.dart';

import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapCoinSelectionBottomSheet extends StatelessWidget {
  const SwapCoinSelectionBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    // D7: frozen coins are never selectable for spending — hide them so the
    // sheet only ever offers spendable outputs (mirrors Send).
    final utxos = context
        .select((TransferBloc bloc) => bloc.state.utxos ?? <Coin>[])
        .where((u) => !u.frozen)
        .toList();

    final selectedUtxos = context.select(
      (TransferBloc bloc) => bloc.state.selectedUtxos,
    );

    final exchangeRate = context.select(
      (TransferBloc bloc) => bloc.state.exchangeRate,
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

    final labels = context.swapCopyForLocale;
    final selectable = {for (final coin in utxos) coin.outpoint: coin};
    return CoinSelectionSheet(
      bitcoinUnit: bitcoinUnit,
      exchangeRate: exchangeRate,
      fiatCurrency: fiatCurrency,
      coins: [
        for (final coin in utxos)
          (
            outpoint: coin.outpoint,
            amount: Sats(coin.amountSat),
            address: switch (coin) {
              BitcoinCoin(:final address) => address ?? '',
              LiquidCoin(:final confidentialAddress) => confidentialAddress,
            },
            addressType: switch (coin) {
              BitcoinCoin(keychain: Keychain.internal) =>
                labels.coinsKeychainChange,
              _ => labels.coinsKeychainReceive,
            },
          ),
      ],
      initialSelection: {for (final coin in selectedUtxos) coin.outpoint},
      requestedAmount: Sats.fromInt(amountToSendSat),
      labels: (
        title: labels.selectAmountTitle,
        close: labels.closeDialogButton,
        requested: labels.amountRequestedLabel,
        insufficient: labels.sendSelectedUtxosInsufficient,
        address: labels.addressLabel,
        type: labels.typeLabel,
        done: labels.doneButton,
      ),
      addressBuilder: (address, style, color) => Semantics(
        label: '${labels.addressLabel}: $address',
        button: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: AddressViewer(address, style: style, color: color),
        ),
      ),
      onDone: (selection) => context.read<TransferBloc>().add(
        TransferEvent.utxosSelected([
          for (final outpoint in selection) ?selectable[outpoint],
        ]),
      ),
    );
  }
}
