import 'package:exchange/src/recipients/data/sepa_virtual_payee_status_mapper.dart';
import 'package:exchange/src/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:exchange/src/domain/exchange_failure.dart';
import 'package:exchange/src/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// [SepaVirtualPayeeRepository] on the `bbx_api` package.
final class BbxApiSepaVirtualPayeeRepository
    implements SepaVirtualPayeeRepository {
  final bbx.Bbx _mainnet;
  final bbx.Bbx _testnet;

  static const _pageSize = 50;
  static const _maxPages = 20;

  const BbxApiSepaVirtualPayeeRepository({
    required this._mainnet,
    required this._testnet,
  });

  @override
  Future<Result<SepaVirtualPayeeStatus, ExchangeFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  }) async {
    try {
      return (await _api(isTestnet).recipients
              .activateSepaVirtualPayee(recipientId))
          .map(_status)
          .mapErr(
            (failure) => _failureFrom(
              failure,
              'activate the virtual payee',
              ExchangeUnexpectedFailure.new,
            ),
          );
    } on Exception catch (e, st) {
      return Err(
        _unexpected(
          e,
          st,
          'activate the virtual payee',
          ExchangeUnexpectedFailure.new,
        ),
      );
    }
  }

  @override
  Future<Result<SepaVirtualPayeeStatus?, ExchangeFailure>> findStatus({
    required String recipientId,
    required bool isTestnet,
  }) async {
    try {
      final recipients = _api(isTestnet).recipients;
      for (var page = 1; page <= _maxPages; page++) {
        final result = await recipients.listSepaVirtualPayees(
          page: page,
          pageSize: _pageSize,
        );
        switch (result) {
          case Err(:final failure):
            return Err(
              _failureFrom(
                failure,
                'read the virtual payee status',
                ExchangeRecipientsLoadFailure.new,
              ),
            );
          case Ok(:final value):
            for (final payee in value.payees) {
              if (payee.recipientId != recipientId) continue;
              final status = _status(payee);
              if (status == SepaVirtualPayeeStatus.pending) {
                // Listing reads the saved status. Activation is idempotent and
                // refreshes an existing payee from Fiat Republic.
                final refreshed = await recipients.activateSepaVirtualPayee(
                  recipientId,
                );
                return switch (refreshed) {
                  Ok(:final value) => Ok(_status(value)),
                  Err(:final failure) => Err(
                    _failureFrom(
                      failure,
                      'read the virtual payee status',
                      ExchangeRecipientsLoadFailure.new,
                    ),
                  ),
                };
              }
              return Ok(status);
            }
            if (page * _pageSize >= value.totalElements.toInt()) {
              return const Ok(null);
            }
        }
      }
      return const Ok(null);
    } on Exception catch (e, st) {
      return Err(
        _unexpected(
          e,
          st,
          'read the virtual payee status',
          ExchangeRecipientsLoadFailure.new,
        ),
      );
    }
  }

  bbx.Bbx _api(bool isTestnet) => isTestnet ? _testnet : _mainnet;

  static SepaVirtualPayeeStatus _status(bbx.SepaVirtualPayee payee) =>
      sepaVirtualPayeeStatusFromApi(payee.virtualPayeeStatus);

  static ExchangeFailure _failureFrom(
    bbx.BbxFailure failure,
    String operation,
    ExchangeFailure Function([String?]) onApiFailure,
  ) {
    switch (failure) {
      case bbx.BbxMissingCredentialFailure():
        return const ExchangeNotAuthenticatedFailure();
      case bbx.BbxCredentialUnavailableFailure():
        return onApiFailure('Exchange credential unavailable');
      case bbx.BbxRpcFailure() || bbx.BbxHttpFailure():
        final description = '$failure';
        log.warning('API refused to $operation — $description');
        return onApiFailure(description);
      case bbx.BbxTimeoutFailure(:final kind):
        log.warning(
          'Could not reach the API to $operation: ${_timeoutName(kind)}',
        );
        return const ExchangeNetworkFailure();
      case bbx.BbxConnectionFailure():
        log.warning('Could not reach the API to $operation: connectionError');
        return const ExchangeNetworkFailure();
      case bbx.BbxOrderLimitFailure() ||
          bbx.BbxConfidentialSepaInactiveFailure() ||
          bbx.BbxBadCertificateFailure() ||
          bbx.BbxRequestCancelledFailure() ||
          bbx.BbxTransformTimeoutFailure() ||
          bbx.BbxTransportFailure() ||
          bbx.BbxOutcomeUnknownFailure() ||
          bbx.BbxResponseFormatFailure():
        log.warning(
          'Failed to $operation',
          error: failure.runtimeType,
          trace: StackTrace.current,
        );
        return onApiFailure();
    }
  }

  /// The failure for an exception thrown while mapping a response the API
  /// did send.
  static ExchangeFailure _unexpected(
    Exception e,
    StackTrace st,
    String operation,
    ExchangeFailure Function([String?]) onApiFailure,
  ) {
    log.warning('Failed to $operation', error: e.runtimeType, trace: st);
    return onApiFailure();
  }

  static String _timeoutName(bbx.BbxTimeoutKind kind) => switch (kind) {
    bbx.BbxTimeoutKind.connect => 'connectionTimeout',
    bbx.BbxTimeoutKind.send => 'sendTimeout',
    bbx.BbxTimeoutKind.receive => 'receiveTimeout',
  };
}
