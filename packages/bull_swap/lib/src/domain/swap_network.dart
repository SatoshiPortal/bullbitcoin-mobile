enum SwapNetwork {
  bitcoin,
  liquid,
  lightning;

  static SwapNetwork fromName(String value) => values.firstWhere(
    (n) => n.name == value,
    orElse: () => throw ArgumentError('Unknown SwapNetwork: $value'),
  );
}

enum SwapEnvironment {
  mainnet,
  testnet;

  static SwapEnvironment fromName(String value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw ArgumentError('Unknown SwapEnvironment: $value'),
  );
}
