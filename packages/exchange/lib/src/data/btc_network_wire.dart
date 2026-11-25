import 'package:bbx_api/bbx_api.dart' as bbx;

import '../domain/entities/btc_network.dart';

/// A [BtcNetwork] read from the wire, or the raw value this build does not
/// know. Never a silent default.
sealed class ParsedBtcNetwork {
  const ParsedBtcNetwork();
}

final class KnownBtcNetwork extends ParsedBtcNetwork {
  final BtcNetwork network;

  const KnownBtcNetwork(this.network);

  @override
  bool operator ==(Object other) =>
      other is KnownBtcNetwork && other.network == network;

  @override
  int get hashCode => network.hashCode;
}

final class UnknownBtcNetwork extends ParsedBtcNetwork {
  final String raw;

  const UnknownBtcNetwork(this.raw);

  @override
  bool operator ==(Object other) =>
      other is UnknownBtcNetwork && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;
}

/// The only mappings between [BtcNetwork] and the API's wire values, one per
/// wire context.
abstract final class BtcNetworkWire {
  /// The `network` / `bitcoinNetwork` parameter of buy, sell and pay orders.
  static String orderNetwork(BtcNetwork network) => switch (network) {
    BtcNetwork.bitcoin => 'bitcoin',
    BtcNetwork.liquid => 'liquid',
    BtcNetwork.lightning => 'lightning',
  };

  /// The `recipientType` of a bitcoin payout address (default wallets, DCA).
  static String recipientType(BtcNetwork network) => switch (network) {
    BtcNetwork.bitcoin => 'OUT_BITCOIN_ADDRESS',
    BtcNetwork.liquid => 'OUT_LIQUID_ADDRESS',
    BtcNetwork.lightning => 'OUT_LIGHTNING_ADDRESS',
  };

  /// Every [recipientType] value, for list filters, in the order the API
  /// has always been sent them.
  static List<String> get recipientTypes => [
    recipientType(BtcNetwork.bitcoin),
    recipientType(BtcNetwork.lightning),
    recipientType(BtcNetwork.liquid),
  ];

  static ParsedBtcNetwork parseRecipientType(String raw) {
    for (final network in BtcNetwork.values) {
      if (recipientType(network) == raw) return KnownBtcNetwork(network);
    }
    return UnknownBtcNetwork(raw);
  }

  /// [recipientType] as the `bbx_api` DCA call takes it.
  static bbx.DcaRecipientType dcaRecipientType(BtcNetwork network) =>
      switch (network) {
        BtcNetwork.bitcoin => bbx.DcaRecipientType.bitcoinAddress,
        BtcNetwork.liquid => bbx.DcaRecipientType.liquidAddress,
        BtcNetwork.lightning => bbx.DcaRecipientType.lightningAddress,
      };
}
