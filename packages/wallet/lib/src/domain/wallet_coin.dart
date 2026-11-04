import 'package:wallet/wallet.dart' show WalletCoinPort, WalletAddressKeyChain;
import 'dart:typed_data';

import 'package:primitives/primitives.dart' show Outpoint;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_coin.freezed.dart';

@freezed
sealed class WalletCoin with _$WalletCoin implements WalletCoinPort {
  factory WalletCoin.bitcoin({
    required String walletId,
    required String txId,
    required int vout,
    required Uint8List scriptPubkey,
    required BigInt amountSat,
    required String address,
    @Default(WalletAddressKeyChain.external)
    WalletAddressKeyChain addressKeyChain,
    @Default(false) bool isFrozen,
    @Default(0) int confirmations,
  }) = BitcoinWalletCoin;

  factory WalletCoin.liquid({
    required String walletId,
    required String txId,
    required int vout,
    required String scriptPubkey,
    required BigInt amountSat,
    required String standardAddress,
    required String confidentialAddress,
    @Default(WalletAddressKeyChain.external)
    WalletAddressKeyChain addressKeyChain,
    @Default(false) bool isFrozen,
    @Default(0) int confirmations,
  }) = LiquidWalletCoin;

  const WalletCoin._();

  /// Use this to ask "same coin?". `==` also compares labels and
  /// confirmations, which change between reads.
  Outpoint get outpoint => (txId: txId, vout: vout);

  String get address => switch (this) {
    BitcoinWalletCoin(:final address) => address,
    LiquidWalletCoin(:final confidentialAddress) => confidentialAddress,
  };

  /// Whether the UTXO has at least one confirmation (threshold 1).
  bool get isConfirmed => confirmations > 0;
}
