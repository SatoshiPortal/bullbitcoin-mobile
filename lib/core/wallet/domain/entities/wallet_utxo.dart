import 'dart:typed_data';

import 'package:bb_mobile/core/labels/domain/labelable.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_utxo.freezed.dart';

@freezed
sealed class WalletUtxo with _$WalletUtxo implements Labelable {
  factory WalletUtxo.bitcoin({
    required String walletId,
    required String txId,
    required int vout,
    required Uint8List scriptPubkey,
    required BigInt amountSat,
    required String address,
    @Default(WalletAddressKeyChain.external)
    WalletAddressKeyChain addressKeyChain,
    @Default([]) List<String> labels,
    @Default([]) List<String> addressLabels,
    @Default(false) bool isFrozen,
  }) = BitcoinWalletUtxo;
  factory WalletUtxo.liquid({
    required String walletId,
    required String txId,
    required int vout,
    required String scriptPubkey,
    required BigInt amountSat,
    required String standardAddress,
    required String confidentialAddress,
    @Default(WalletAddressKeyChain.external)
    WalletAddressKeyChain addressKeyChain,
    @Default([]) List<String> labels,
    @Default([]) List<String> addressLabels,
    @Default(false) bool isFrozen,
  }) = LiquidWalletUtxo;
  const WalletUtxo._();

  @override
  String get labelRef => '$txId:$vout';

  String get address => when(
        bitcoin: (
          String walletId,
          String txId,
          int vout,
          Uint8List scriptPubkey,
          BigInt amountSat,
          String address,
          WalletAddressKeyChain addressKeyChain,
          List<String> labels,
          List<String> addressLabels,
          bool isFrozen,
        ) =>
            address,
        liquid: (
          String walletId,
          String txId,
          int vout,
          String scriptPubkey,
          BigInt amountSat,
          String standardAddress,
          String confidentialAddress,
          WalletAddressKeyChain addressKeyChain,
          List<String> labels,
          List<String> addressLabels,
          bool isFrozen,
        ) =>
            confidentialAddress,
      );
}
