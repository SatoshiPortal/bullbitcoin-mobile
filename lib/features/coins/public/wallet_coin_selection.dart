import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:coins/coins.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show Keychain;

import '../domain/wallet_utxo.dart';

/// Projects the app's Coins read model onto the workspace selection sheet.
/// Wallet lookup and spending policy stay outside the sheet.
Widget walletCoinSelection({
  required BuildContext context,
  required BitcoinUnit bitcoinUnit,
  required double? exchangeRate,
  required String fiatCurrency,
  required List<WalletUtxo> utxos,
  required List<WalletUtxo> initialSelectedUtxos,
  required int amountToSendSat,
  required ValueChanged<List<WalletUtxo>> onDone,
}) {
  final labels = context.loc;
  final selectable = {
    for (final coin in utxos)
      if (!coin.isFrozen) coin.outpoint: coin,
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
          address: coin.address,
          addressType: coin.addressKeyChain == Keychain.external
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
        child: AddressViewer(address, style: style, color: color),
      ),
    ),
    onDone: (selection) =>
        onDone([for (final outpoint in selection) ?selectable[outpoint]]),
  );
}
