import 'dart:typed_data';

import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet_address.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_utxo.freezed.dart';

@freezed
sealed class WalletUtxo with _$WalletUtxo {
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

  String get address => switch (this) {
    BitcoinWalletUtxo(:final address) => address,
    LiquidWalletUtxo(:final confidentialAddress) => confidentialAddress,
  };
}
