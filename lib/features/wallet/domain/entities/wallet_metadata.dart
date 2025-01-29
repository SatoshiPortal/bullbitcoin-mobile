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
