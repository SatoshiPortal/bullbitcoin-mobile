import 'package:primitives/primitives.dart' show BitcoinNetwork;

/// An exact chain checkpoint. Scanning starts strictly after this block.
final class BitcoinSyncCheckpoint {
  final int height;
  final String blockHash;

  /// Header time in UTC seconds, when known from the verified catalogue.
  final int? blockTimestamp;

  DateTime? get timestamp => switch (blockTimestamp) {
    final seconds? => DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ),
    null => null,
  };

  BitcoinSyncCheckpoint({
    required this.height,
    required this.blockHash,
    this.blockTimestamp,
  }) {
    if (height < 0) throw ArgumentError.value(height, 'height');
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(blockHash)) {
      throw ArgumentError.value(blockHash, 'blockHash');
    }
  }

  const BitcoinSyncCheckpoint._(
    this.height,
    this.blockHash,
    this.blockTimestamp,
  );

  factory BitcoinSyncCheckpoint.genesis(BitcoinNetwork network) =>
      BitcoinSyncCheckpoint._(
        0,
        switch (network) {
          BitcoinNetwork.mainnet =>
            '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f',
          BitcoinNetwork.testnet =>
            '000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943',
          BitcoinNetwork.signet =>
            '00000008819873e925422c1ff0f99f7cc9bbb232af63a077a480a3633bee1ef6',
          BitcoinNetwork.regtest =>
            '0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206',
        },
        switch (network) {
          BitcoinNetwork.mainnet => 1231006505,
          BitcoinNetwork.testnet || BitcoinNetwork.regtest => 1296688602,
          BitcoinNetwork.signet => 1598918400,
        },
      );

  /// The block immediately before mainnet SegWit activation.
  static const segwit = BitcoinSyncCheckpoint._(
    481823,
    '000000000000000000cbeff0b533f8e1189cf09dfbebf57a8ebe349362811b80',
    1503539571,
  );

  /// Last block strictly before BIP32's publication date, 2012-02-01 UTC.
  static const bip32 = BitcoinSyncCheckpoint._(
    164780,
    '000000000000087bb253be417ce7df3235a812350d1e05a4c224c4fc448cceef',
    1328053905,
  );

  /// The block immediately before the first Taproot block (709632).
  static const taproot = BitcoinSyncCheckpoint._(
    709631,
    '000000000000000000013712fc242ee6dd28476d0e9c931c75f83e6974c6bccc',
    1636865834,
  );

  @override
  bool operator ==(Object other) =>
      other is BitcoinSyncCheckpoint &&
      height == other.height &&
      blockHash == other.blockHash;

  @override
  int get hashCode => Object.hash(height, blockHash);
}
