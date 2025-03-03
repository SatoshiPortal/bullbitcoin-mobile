import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_metadata.freezed.dart';

enum Network {
  bitcoinMainnet(
    coinType: 0,
    isBitcoin: true,
    isLiquid: false,
    isMainnet: true,
    isTestnet: false,
  ),
  bitcoinTestnet(
    coinType: 1,
    isBitcoin: true,
    isLiquid: false,
    isMainnet: false,
    isTestnet: true,
  ),
  liquidMainnet(
    coinType: 1776,
    isBitcoin: false,
    isLiquid: true,
    isMainnet: true,
    isTestnet: false,
  ),
  liquidTestnet(
    coinType: 1,
    isBitcoin: false,
    isLiquid: true,
    isMainnet: false,
    isTestnet: true,
  );

  final int coinType;
  final bool isBitcoin;
  final bool isLiquid;
  final bool isMainnet;
  final bool isTestnet;

  const Network({
    required this.coinType,
    required this.isBitcoin,
    required this.isLiquid,
    required this.isMainnet,
    required this.isTestnet,
  });

  factory Network.fromName(String name) {
    return Network.values.firstWhere((network) => network.name == name);
  }

  factory Network.fromEnvironment({
    required bool isTestnet,
    required bool isLiquid,
  }) {
    if (isLiquid) {
      return isTestnet ? liquidTestnet : liquidMainnet;
    } else {
      return isTestnet ? bitcoinTestnet : bitcoinMainnet;
    }
  }
}

enum ScriptType {
  bip84(purpose: 84),
  bip49(purpose: 49),
  bip44(purpose: 44);

  final int purpose;

  const ScriptType({required this.purpose});

  static ScriptType fromName(String name) {
    return ScriptType.values.firstWhere((script) => script.name == name);
  }
}

enum WalletSource {
  mnemonic,
  xpub,
  descriptors,
  coldcard;

  static WalletSource fromName(String name) {
    return WalletSource.values.firstWhere((source) => source.name == name);
  }
}

@freezed
class WalletMetadata with _$WalletMetadata {
  const factory WalletMetadata({
    required String id,
    @Default('') String label,
    required Network network,
    @Default(false) bool isDefault,
    // The fingerprint of the BIP32 root/master key (if a seed was used to derive the wallet)
    @Default('') String masterFingerprint,
    required String xpubFingerprint,
    required ScriptType scriptType,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required WalletSource source,
  }) = _WalletMetadata;
  const WalletMetadata._();
}
