import 'package:bbx_api/src/bbx_failure.dart';
import 'package:bbx_api/src/bbx_transport.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/prices/prices_wire.dart';
import 'package:bbx_api/src/prices/user_rate.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The `public/price` endpoint.
final class PricesApi {
  static const endpoint = '/public/price';

  final BbxTransport _transport;

  @internal
  PricesApi(this._transport);

  /// The user's rate from [fromCurrency] to [toCurrency]. The server wraps
  /// it in `element` or returns it as the result itself; both are read.
  Future<Result<UserRate, BbxFailure>> getUserRate({
    required String fromCurrency,
    required String toCurrency,
  }) => _transport.request(
    endpoint,
    'getUserRate',
    params: {
      'element': {'fromCurrency': fromCurrency, 'toCurrency': toCurrency},
    },
    read: (result) {
      final element = read<Map<String, dynamic>>(result, 'result');
      return parseUserRate(
        read<Map<String, dynamic>>(element['element'] ?? element, 'element'),
      );
    },
  );
}
