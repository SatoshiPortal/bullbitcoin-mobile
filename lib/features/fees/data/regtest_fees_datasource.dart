import 'package:electrum/setup.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:sync/sync.dart' show WalletConnection, estimateBitcoinFees;

/// Uses only the selected regtest Electrum connection; no public fee service.
class RegtestFeesDatasource {
  const RegtestFeesDatasource();

  /// Throws when the server has no estimate, so the next server is tried.
  Future<FeeOptions> fetch(ElectrumConnection connection) async {
    final estimates = switch (await estimateBitcoinFees(
      WalletConnection(
        url: connection.url,
        timeout: Duration(seconds: connection.effectiveTimeout),
        retry: connection.retry,
        stopGap: connection.stopGap,
        validateDomain: connection.validateDomain,
        socks5: connection.socks5,
      ),
      targets: const [1, 3, 6],
    )) {
      Ok(:final value) => value,
      Err() => throw const FormatException('Fee estimates unavailable'),
    };
    return FeeOptions(
      minRelay: const RelativeFee(NetworkFeeRelayPolicy.minRelaySatPerKwu),
      fastest: fromEstimate(estimates[0]),
      economic: fromEstimate(estimates[1]),
      slow: fromEstimate(estimates[2]),
    );
  }

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
