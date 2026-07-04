import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/labels/label.dart';
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
    // Unblinded asset id (hex) of this output, from LWK's TxOutSecrets. For
    // L-BTC this equals the network's L-BTC asset id.
    required String assetIdHex,
    // The wallet address index this output was received at. Nullable because
    // it is unknown for watch-only / foreign outputs.
    required int? addressIndex,
    // SLIP-77 value blinding factor (hex) for this output, from TxOutSecrets.
    // Used by the LUD-22 proof-of-funds factor-reconstruction contract.
    required String valueBf,
    // SLIP-77 asset blinding factor (hex) for this output, from TxOutSecrets.
    required String assetBf,
    @Default(WalletAddressKeyChain.external)
    WalletAddressKeyChain addressKeyChain,
    @Default([]) List<Label> labels,
    @Default([]) List<Label> txLabels,
    @Default([]) List<Label> addressLabels,
    @Default(false) bool isFrozen,
    @Default(0) int confirmations,
  }) = LiquidWalletUtxo;

  const WalletUtxo._();

  String get address => switch (this) {
    BitcoinWalletUtxo(:final address) => address,
    LiquidWalletUtxo(:final confidentialAddress) => confidentialAddress,
  };

  /// Whether the UTXO has at least one confirmation (threshold 1).
  bool get isConfirmed => confirmations > 0;
}
