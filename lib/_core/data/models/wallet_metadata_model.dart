import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_metadata_model.freezed.dart';
part 'wallet_metadata_model.g.dart';

@freezed
class WalletMetadataModel with _$WalletMetadataModel {
  factory WalletMetadataModel({
    @Default('') String masterFingerprint,
    required String xpubFingerprint,
    required bool isBitcoin,
    required bool isLiquid,
    required bool isMainnet,
    required bool isTestnet,
    required String scriptType,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required String source,
    @Default(false) bool isDefault,
    @Default('') String label,
  }) = _WalletMetadataModel;
  const WalletMetadataModel._();

  factory WalletMetadataModel.fromJson(Map<String, Object?> json) =>
      _$WalletMetadataModelFromJson(json);

  // The network name is important since the same coin type and script types
  //  are used in for example bitcoin and liquid testnet, so we need to include
  //  the network name in the id to differentiate wallets from different
  //  networks with the same xpub/seed.
  String get id =>
      '$xpubFingerprint:${isLiquid ? 'liquid' : 'bitcoin'}:${isTestnet ? 'testnet' : 'mainnet'}';
}
