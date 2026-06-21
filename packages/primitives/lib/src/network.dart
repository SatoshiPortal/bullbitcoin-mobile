/// Bitcoin / Liquid network. Ported verbatim from the app's
/// `lib/core/wallet/domain/entities/wallet.dart` so the two definitions stay
/// byte-compatible until the app re-points its imports here.
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

  /// Non-throwing parse for untrusted/persisted input.
  static Network? tryFromName(String name) {
    for (final n in Network.values) {
      if (n.name == name) return n;
    }
    return null;
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
