import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:bb_mobile/features/labels/label.dart';

/// Builds a [WalletUtxo] (Bitcoin variant) for tests with sensible defaults.
///
/// [labels] is a list of plain label strings; each becomes a [Label] of type
/// [LabelType.address] keyed by the synthetic outpoint.
WalletUtxo walletUtxoFixture({
  int confirmations = 1,
  bool isFrozen = false,
  WalletAddressKeyChain keychain = WalletAddressKeyChain.external,
  List<String> labels = const [],
  int sats = 100000,
  String? txId,
  int vout = 0,
  String walletId = 'wallet-1',
  String? address,
}) {
  final resolvedTxId = txId ?? 'tx-$sats-$vout-${confirmations}f$isFrozen';
  final resolvedAddress = address ?? 'bc1qaddr$resolvedTxId';
  return WalletUtxo.bitcoin(
    walletId: walletId,
    txId: resolvedTxId,
    vout: vout,
    scriptPubkey: Uint8List(0),
    amountSat: BigInt.from(sats),
    address: resolvedAddress,
    addressKeyChain: keychain,
    isFrozen: isFrozen,
    confirmations: confirmations,
    labels: [
      for (var i = 0; i < labels.length; i++)
        Label.addr(id: i, address: resolvedAddress, label: labels[i]),
    ],
  );
}
