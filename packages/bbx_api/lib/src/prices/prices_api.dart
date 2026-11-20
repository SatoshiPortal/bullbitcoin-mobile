import 'package:bbx_api/src/bbx_api_client.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/prices/user_rate.dart';

/// The `public/price` endpoint.
class PricesApi {
  static const endpoint = '/public/price';

  final BbxApiClient _client;

  PricesApi(this._client);

  /// The user's rate from [fromCurrency] to [toCurrency]. The server wraps
  /// it in `element` or returns it as the result itself; both are read.
  Future<UserRate> getUserRate({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final result = read<Map<String, dynamic>>(
      await _client.call(
        endpoint,
        'getUserRate',
        params: {
          'element': {'fromCurrency': fromCurrency, 'toCurrency': toCurrency},
        },
      ),
      'result',
    );
    return UserRate.fromJson(
      read<Map<String, dynamic>>(result['element'] ?? result, 'element'),
    );
  }
}
