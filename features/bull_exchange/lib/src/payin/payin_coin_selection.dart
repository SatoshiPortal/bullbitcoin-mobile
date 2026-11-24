import 'package:bull_ui/bull_ui.dart';
import 'package:coins/coins.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show Coin, BitcoinCoin, Keychain;

import '../exchange_l10n.dart';
import 'exchange_payin_ui.dart';

Widget payinCoinSelection({
  required BuildContext context,
  required BitcoinUnit bitcoinUnit,
  required double? exchangeRate,
  required String fiatCurrency,
  required List<Coin> utxos,
  required List<Coin> initialSelectedUtxos,
  required int amountToSendSat,
  required ValueChanged<List<Coin>> onDone,
}) {
  final labels = context.loc;
  final selectable = {
    for (final coin in utxos.whereType<BitcoinCoin>())
      if (!coin.frozen) coin.outpoint: coin,
  };
  return CoinSelectionSheet(
    bitcoinUnit: bitcoinUnit,
    exchangeRate: exchangeRate,
    fiatCurrency: fiatCurrency,
    coins: [
      for (final coin in selectable.values)
        (
          outpoint: coin.outpoint,
          amount: Sats(coin.amountSat),
          address: coin.address ?? '',
          addressType: coin.keychain == Keychain.external
              ? labels.coinsKeychainReceive
              : labels.coinsKeychainChange,
        ),
    ],
    initialSelection: {for (final coin in initialSelectedUtxos) coin.outpoint},
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
        child: context.read<ExchangePayinUi>().addressViewer(
          context,
          address,
          style: style,
          color: color,
        ),
      ),
    ),
    onDone: (selection) =>
        onDone([for (final outpoint in selection) ?selectable[outpoint]]),
  );
}
