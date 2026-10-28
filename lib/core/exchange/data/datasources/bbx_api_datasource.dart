import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bbx_api/bbx_api.dart';
import 'package:bb_mobile/core/exchange/data/mappers/bbx_api_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_failure.dart';
import 'package:bull_logger/bull_logger.dart' show log;

/// The shared Bull Bitcoin API client (`bbx_api`) for one environment.
class BbxApiDatasource {
  static const mainnetInstanceName = 'mainnetBbxApi';
  static const testnetInstanceName = 'testnetBbxApi';

  final bbx.BbxApi _client;

  BbxApiDatasource(this._client);

  bbx.UserRepo get users => _client.users;
  bbx.OrderRepo get orders => _client.orders;
  bbx.PricerRepo get prices => _client.pricer;
  bbx.KYCRepo get kyc => _client.kyc;
  RecipientRepo get recipients => _client.recipients;
  MessageRepo get messages => _client.messages;

  late final NotificationSocketService notifications =
      NotificationSocketService(webSocketRepo: _client.notificationSocket);
}

/// A failed `bbx_api` call, thrown by [BbxApiResultX.unwrap].
///
/// [toString] carries the code only: the message can echo request data.
class BbxApiException extends ExchangeApiException {
  final bbx.ApiError error;

  const BbxApiException(this.error);

  @override
  ExchangeApiFailure get failure => BbxApiMapper.apiFailure(error);

  @override
  String toString() => 'BbxApiException(code: ${error.code ?? 'none'})';
}

extension BbxApiResultX<T> on bbx.ApiResult<T> {
  /// The data, or a [BbxApiException] carrying the error.
  T unwrap() => switch (this) {
    bbx.Success(:final data) => data,
    bbx.Failure(:final error) => throw BbxApiException(
      error..reportBadCertificate(),
    ),
  };
}

extension BbxApiErrorX on bbx.ApiError {
  /// Sends a rejected TLS certificate to the crash reporter: it can mean the
  /// connection is intercepted.
  void reportBadCertificate() {
    if (kind != bbx.ApiErrorKind.badCertificate) return;
    log.severe(
      message: 'Exchange API TLS certificate rejected',
      error: this,
      trace: StackTrace.current,
    );
  }

  bool get isUnreachable =>
      kind == bbx.ApiErrorKind.network || kind == bbx.ApiErrorKind.timeout;

  bool get isApiKeyMissing => kind == bbx.ApiErrorKind.unauthenticated;
}
