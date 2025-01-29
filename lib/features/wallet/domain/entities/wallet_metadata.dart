enum WalletNetwork {
  bitcoin,
  liquid;

  static WalletNetwork fromName(String name) {
    return WalletNetwork.values.firstWhere((network) => network.name == name);
  }
}

enum WalletEnvironment {
  mainnet,
  testnet;

  static WalletEnvironment fromName(String name) {
    return WalletEnvironment.values.firstWhere((env) => env.name == name);
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
class WalletMetadata {
  final String id;
  final String label;
  final WalletNetwork network;
  final WalletEnvironment environment;
  final WalletScriptType scriptType;
  final WalletSource source;

  WalletMetadata({
    required this.id,
    required this.label,
    required this.network,
    required this.environment,
    required this.scriptType,
    required this.source,
  });
}
