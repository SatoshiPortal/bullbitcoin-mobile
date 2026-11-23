import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinFeesPort;
import 'package:primitives/primitives.dart';

import '../fees.dart';

extension FeesPayjoin on Fees {
  /// Supplies live estimates for Payjoin's receiver fee cap.
  PayjoinFeesPort get payjoin => _PayjoinFeesAdapter(this);
}

final class _PayjoinFeesAdapter implements PayjoinFeesPort {
  final Fees _fees;

  const _PayjoinFeesAdapter(this._fees);

  @override
  Future<FeeRate> fastestFeeRate({required BitcoinNetwork network}) async {
    return switch (await _fees.estimate(network)) {
      Ok(:final value) => FeeRate(value.fastest.value.toDouble()),
      Err() => throw Exception('Fee estimation unavailable'),
    };
  }
}
