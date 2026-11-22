import 'package:fees/fees.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' hide Network;

final class AppPayjoinFeesAdapter implements PayjoinFeesPort {
  final Fees _fees;

  const AppPayjoinFeesAdapter(this._fees);

  @override
  Future<FeeRate> fastestFeeRate({required BitcoinNetwork network}) async {
    return switch (await _fees.estimate(network)) {
      Ok(:final value) => FeeRate(value.fastest.value.toDouble()),
      Err() => throw Exception('Fee estimation unavailable'),
    };
  }
}
