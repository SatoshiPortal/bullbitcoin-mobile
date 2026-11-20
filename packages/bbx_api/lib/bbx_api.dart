/// Client for the Bull Bitcoin exchange API.
///
/// Transport and wire models only. Callers configure the [Dio] client (base
/// URL, timeouts, authentication) and map the wire models to their own types.
library;

export 'src/bbx_api_client.dart';
export 'src/bbx_api_exception.dart';
export 'src/orders/order_stats.dart';
export 'src/orders/orders_api.dart';
