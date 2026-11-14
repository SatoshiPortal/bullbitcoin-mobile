import 'dart:isolate';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

/// Uses only the selected regtest Electrum connection; no public fee service.
class RegtestFeesDatasource {
  const RegtestFeesDatasource();

  Future<FeeOptions> fetch(ElectrumConnection connection) => Isolate.run(() {
    final client = bdk.ElectrumClient(
      url: connection.url,
      socks5: connection.socks5,
      timeout: connection.effectiveTimeout.clamp(0, 255),
      retry: connection.retry.clamp(0, 255),
      validateDomain: connection.validateDomain,
    );
    try {
      return FeeOptions(
        minRelay: const RelativeFee(NetworkFeeRelayPolicy.minRelaySatPerKwu),
        fastest: fromEstimate(client.estimateFee(number: 1)),
        economic: fromEstimate(client.estimateFee(number: 3)),
        slow: fromEstimate(client.estimateFee(number: 6)),
      );
    } finally {
      client.dispose();
    }
  });

  /// Electrum blockchain.estimatefee returns BTC/kB, or -1 if unavailable.
  /// https://electrum-protocol.readthedocs.io/en/latest/protocol-methods.html#blockchain-estimatefee
  static RelativeFee fromEstimate(double bitcoinPerKilobyte) {
    if (!bitcoinPerKilobyte.isFinite || bitcoinPerKilobyte <= 0) {
      throw const FormatException('Fee estimate unavailable');
    }
    final fee = NetworkFee.relativeFromSatPerVbyte(bitcoinPerKilobyte * 100000);
    if (fee.satPerKwu <= 0) {
      throw const FormatException('Fee estimate below precision');
    }
    return fee;
  }
}
