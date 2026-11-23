import 'dart:typed_data';

import 'package:labels/labels.dart';
import 'package:sync/sync.dart';

import '../domain/wallet_utxo.dart';

class WalletUtxoMapper {
  static WalletUtxo toEntity(
    Coin coin, {
    required String walletId,
    required List<Label> labels,
    required List<Label> txLabels,
    required List<Label> addressLabels,
  }) => switch (coin) {
    BitcoinCoin() => WalletUtxo.bitcoin(
      walletId: walletId,
      txId: coin.outpoint.txId,
      vout: coin.outpoint.vout,
      amountSat: coin.amountSat,
      scriptPubkey: Uint8List.fromList(coin.scriptPubkey),
      address: coin.address ?? '',
      addressKeyChain: coin.keychain,
      labels: labels,
      txLabels: txLabels,
      addressLabels: addressLabels,
      isFrozen: coin.frozen,
      confirmations: coin.confirmations,
    ),
    LiquidCoin() => WalletUtxo.liquid(
      walletId: walletId,
      txId: coin.outpoint.txId,
      vout: coin.outpoint.vout,
      amountSat: coin.amountSat,
      scriptPubkey: coin.scriptPubkey,
      standardAddress: coin.standardAddress,
      confidentialAddress: coin.confidentialAddress,
      labels: labels,
      txLabels: txLabels,
      addressLabels: addressLabels,
      isFrozen: coin.frozen,
      blockHeight: coin.blockHeight,
    ),
  };
}
