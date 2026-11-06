import 'package:primitives/primitives.dart';

/// Stable identity. Engine, connection settings and endpoints are not identity.
final class WalletKey {
  final String id;
  final Network network;

  WalletKey({required this.id, required this.network}) {
    if (id.isEmpty) throw ArgumentError('Wallet id must not be empty');
  }

  @override
  bool operator ==(Object other) =>
      other is WalletKey && other.id == id && other.network == network;

  @override
  int get hashCode => Object.hash(id, network);
}

/// Legacy native location, without IO or normalization of the supplied root.
///
/// The id is encoded as UTF-16 code units, NOT UTF-8 bytes. Liquid receives a
/// root beneath which LWK manages its network and descriptor directories.
/// Existing ids encode the network. This layout must not be used to enable
/// new networks until catalog uniqueness and storage migration are designed.
/// Signet/regtest are refused: their legacy origins share testnet coin type 1.
/// Pass getApplicationDocumentsDirectory().path verbatim as documentsDirectory.
String nativeWalletStoragePath(String documentsDirectory, WalletKey key) {
  final hexId = key.id.codeUnits
      .map((unit) => unit.toRadixString(16).padLeft(2, '0'))
      .join();
  final suffix = switch (key.network) {
    BitcoinNetwork.mainnet || BitcoinNetwork.testnet => '_bdk_dart',
    LiquidNetwork.mainnet || LiquidNetwork.testnet => '',
    BitcoinNetwork.signet ||
    BitcoinNetwork.regtest ||
    LiquidNetwork.regtest => throw ArgumentError('Unsupported storage network'),
  };
  return '$documentsDirectory/$hexId$suffix';
}
