/// Canonical Bitcoin genesis block constants, keyed by network.
///
/// Used by `WalletBirthdayCheckpointRepositoryImpl` to resolve a birthday at
/// or before genesis without any HTTP round-trip: the genesis block is a
/// fixed protocol constant (height 0, hardcoded in every Bitcoin node), not
/// something a mempool server needs to be asked about, and no mempool
/// server can be trusted to answer for a moment before its own history
/// starts anyway.
///
/// Values cross-checked against blockstream.info's block explorer API
/// (`GET /api/block-height/0`, `GET /api/block/:hash`) for both networks.
class BitcoinGenesisBlock {
  final int height;
  final String hash;
  final DateTime timestamp;

  BitcoinGenesisBlock._({
    required this.height,
    required this.hash,
    required DateTime timestamp,
  }) : timestamp = timestamp.toUtc();

  static final BitcoinGenesisBlock mainnet = BitcoinGenesisBlock._(
    height: 0,
    hash: '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f',
    timestamp: DateTime.utc(2009, 1, 3, 18, 15, 5),
  );

  static final BitcoinGenesisBlock testnet = BitcoinGenesisBlock._(
    height: 0,
    hash: '000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943',
    timestamp: DateTime.utc(2011, 2, 2, 23, 16, 42),
  );

  /// Picks the constant for [isTestnet]. Bitcoin-only, mirroring
  /// `WalletBirthdayCheckpointDatasource`'s Liquid exclusion — there is no
  /// Liquid variant because compact-block-filter recovery has no Liquid
  /// equivalent.
  factory BitcoinGenesisBlock.forNetwork({required bool isTestnet}) =>
      isTestnet ? testnet : mainnet;
}
