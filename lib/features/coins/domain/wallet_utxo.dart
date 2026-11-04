import 'package:wallet/wallet.dart' show WalletCoinPort, WalletAddressKeyChain;
import 'dart:typed_data';

import 'package:primitives/primitives.dart' show Outpoint;
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_utxo.freezed.dart';

@freezed
sealed class WalletUtxo with _$WalletUtxo implements WalletCoinPort {
  factory WalletUtxo.bitcoin({
    required String walletId,
    required String txId,
    required int vout,
    required Uint8List scriptPubkey,
    required BigInt amountSat,
    required String address,
    @Default(WalletAddressKeyChain.external)
    WalletAddressKeyChain addressKeyChain,
    @Default([]) List<Label> labels,
    @Default([]) List<Label> txLabels,
    @Default([]) List<Label> addressLabels,
    @Default(false) bool isFrozen,
    @Default(0) int confirmations,
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
    @Default([]) List<Label> labels,
    @Default([]) List<Label> txLabels,
    @Default([]) List<Label> addressLabels,
    @Default(false) bool isFrozen,
    @Default(0) int confirmations,
  }) = LiquidWalletUtxo;

  const WalletUtxo._();

  /// Use this to ask "same coin?". `==` also compares labels and
  /// confirmations, which change between reads.
  Outpoint get outpoint => (txId: txId, vout: vout);

  String get address => switch (this) {
    BitcoinWalletUtxo(:final address) => address,
    LiquidWalletUtxo(:final confidentialAddress) => confidentialAddress,
  };

  /// Whether the UTXO has at least one confirmation (threshold 1).
  bool get isConfirmed => confirmations > 0;
}
