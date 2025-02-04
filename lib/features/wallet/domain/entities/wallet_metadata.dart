import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_metadata.freezed.dart';
part 'wallet_metadata.g.dart';

enum Network {
  bitcoin,
  liquid;

  factory Network.fromName(String name) {
    return Network.values.firstWhere((network) => network.name == name);
  }
}

enum NetworkEnvironment {
  mainnet,
  testnet;

  factory NetworkEnvironment.fromName(String name) {
    return NetworkEnvironment.values.firstWhere((env) => env.name == name);
  }
}

enum WalletScriptType {
  bip84,
  bip49,
  bip44;

  static WalletScriptType fromName(String name) {
    return WalletScriptType.values.firstWhere((script) => script.name == name);
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
    required String id,
    required String label,
    required String seedFingerprint,
    required Network network,
    required NetworkEnvironment environment,
    required WalletScriptType scriptType,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required WalletSource source,
  }) = _WalletMetadata;
  const WalletMetadata._();

  factory WalletMetadata.fromJson(Map<String, dynamic> json) =>
      _$WalletMetadataFromJson(json);
}
