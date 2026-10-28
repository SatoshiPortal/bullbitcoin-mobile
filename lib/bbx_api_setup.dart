import 'dart:io';

import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bbx_api/bbx_api.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:get_it/get_it.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Wires the shared Bull Bitcoin API client (`bbx_api`) into the app.
abstract final class BbxApiSetup {
  static const _clientSource = 'BULL Mobile';

  static const _webSocketPingInterval = Duration(seconds: 30);

  /// Bounds every call, including order polling over Tor.
  static const _timeout = Duration(seconds: 30);

  static const orderSummaryParsing = OrderSummaryParsing(
    fallbacks: OrderSummaryFallbacks(
      orderType: bbx.OrderSummaryType.balanceAdjustment,
      orderStatus: bbx.OrderSummaryStatus.inProgress,
      payinStatus: bbx.OrderSummaryPayinStatus.notStarted,
      payoutStatus: bbx.OrderSummaryPayoutStatus.notStarted,
      paymentMethod: bbx.OrderSummaryPaymentMethod.thinAir,
    ),
    skipInvalidListElements: true,
  );

  /// Needs [BullbitcoinApiKeyDatasource] registered first.
  static void setup(GetIt locator) {
    locator.registerLazySingleton<BbxApiDatasource>(
      () => _create(
        baseUrl: ApiServiceConstants.bbApiUrl,
        isTestnet: false,
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
      ),
      instanceName: BbxApiDatasource.mainnetInstanceName,
    );
    locator.registerLazySingleton<BbxApiDatasource>(
      () => _create(
        baseUrl: ApiServiceConstants.bbApiTestUrl,
        isTestnet: true,
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
      ),
      instanceName: BbxApiDatasource.testnetInstanceName,
    );
  }

  static BbxApiDatasource _create({
    required String baseUrl,
    required bool isTestnet,
    required BullbitcoinApiKeyDatasource apiKeyDatasource,
  }) {
    final config = bbx.ApiConfig.apiKey(
      baseUrl,
      apiKeyProvider: () async {
        final apiKey = await apiKeyDatasource.get(isTestnet: isTestnet);
        return apiKey != null && apiKey.isActive ? apiKey.key : null;
      },
      clientSource: _clientSource,
      connectionTimeOut: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
      clientPlatform: const _IoClientPlatform(),
      logger: const _BullLoggerBbxApiLogger(),
      webSocketConnector: _ioWebSocketConnector,
      webSocketPingInterval: _webSocketPingInterval,
      orderSummaryParsing: orderSummaryParsing,
    );
    return BbxApiDatasource(bbx.BbxApi(config));
  }

  static WebSocketChannel _ioWebSocketConnector(
    Uri uri, {
    Map<String, String>? headers,
    Duration? pingInterval,
  }) => IOWebSocketChannel.connect(
    uri,
    headers: headers,
    pingInterval: pingInterval,
  );
}

class _IoClientPlatform extends bbx.NoopBBClientPlatform {
  const _IoClientPlatform();

  @override
  bool isNoConnectionError(Object error) => error is SocketException;

  @override
  int? webSocketRefusalStatus(Object error) => switch (error) {
    WebSocketChannelException(inner: final WebSocketException inner) =>
      inner.httpStatusCode,
    _ => null,
  };
}

/// Routes the package's logs into the app logger.
/// Logs errors as warnings: `severe` goes to the crash reporter.
class _BullLoggerBbxApiLogger implements bbx.BBApiLogger {
  const _BullLoggerBbxApiLogger();

  @override
  void debug(String message) => log.finer('bbx_api: $message');

  @override
  void info(String message) => log.fine('bbx_api: $message');

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      log.warning(
        'bbx_api: $message${error == null ? '' : ' (${error.runtimeType})'}',
        trace: stackTrace,
      );

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      warning(message, error: error, stackTrace: stackTrace);
}
