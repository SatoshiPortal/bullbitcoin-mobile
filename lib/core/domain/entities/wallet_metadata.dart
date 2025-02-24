import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_metadata.freezed.dart';
part 'wallet_metadata.g.dart';

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

// TODO: Analyze if it would make sense to use a sealed WalletMetadata class with the following subclasses:
// - BitcoinWalletMetadata
// - LiquidWalletMetadata
// WalletMetadata class would have some common properties and methods, like label, id, network, source etc. while the subclasses would have specific properties and methods.
// The network property would be used to determine which subclass to use when deriving toEntity in the model.
// This would make sense if there are a lot of differences in the fields or their values between the two types of wallets.
@freezed
class WalletMetadata with _$WalletMetadata {
  const factory WalletMetadata({
    // The fingerprint of the BIP32 root/master key (if a seed was used to derive the wallet)
    @Default('') String masterFingerprint,
    required String xpubFingerprint,
    required Network network,
    required ScriptType scriptType,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required WalletSource source,
    @Default(false) bool isDefault,
    @Default('') String label,
  }) = _WalletMetadata;
  const WalletMetadata._();

  factory WalletMetadata.fromJson(Map<String, dynamic> json) =>
      _$WalletMetadataFromJson(json);

  // The network name is important since the same coin type and script types
  //  are used in for example bitcoin and liquid testnet, so we need to include
  //  the network name in the id to differentiate wallets from different
  //  networks with the same xpub/seed.
  String get id => '$xpubFingerprint:${network.name}';

  // TODO: Add the 'Secure Bitcoin Wallet' and 'Instant Payments Wallet' strings to the localization file
  // and use them in the UI if no label is provided for a mnemonic wallet.
  String get name => label.isEmpty ? _defaultName : label;
  String get _defaultName {
    switch (source) {
      case WalletSource.mnemonic:
        if (network.isBitcoin) {
          return 'Secure Bitcoin Wallet';
        } else {
          return 'Instant Payments Wallet';
        }
      case WalletSource.xpub:
        return 'Xpub:${id.substring(0, 5)}';
      case WalletSource.coldcard:
        return 'Coldcard:${id.substring(0, 5)}';
      case WalletSource.descriptors:
        return 'Imported Descriptor:${id.substring(0, 5)}';
    }
  }
}
