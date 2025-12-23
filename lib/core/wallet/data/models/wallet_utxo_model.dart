import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_utxo_model.freezed.dart';

@freezed
sealed class WalletUtxoModel with _$WalletUtxoModel {
  factory WalletUtxoModel.bitcoin({
    required String txId,
    required int vout,
    required BigInt amountSat,
    required Uint8List scriptPubkey,
    required String address,
    required bool isExternalKeyChain,
  }) = BitcoinWalletUtxoModel;

  factory WalletUtxoModel.liquid({
    required String txId,
    required int vout,
    required BigInt amountSat,
    required String scriptPubkey,
    required String standardAddress,
    required String confidentialAddress,
  }) = LiquidWalletUtxoModel;

  const WalletUtxoModel._();

  String get labelRef => '$txId:$vout';
}
