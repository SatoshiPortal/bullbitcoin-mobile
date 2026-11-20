import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/features/recipients/data/sepa_virtual_payee_status_mapper.dart';
import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';

/// [SepaVirtualPayeeRepository] on the `bbx_api` package.
final class BbxApiSepaVirtualPayeeRepository
    implements SepaVirtualPayeeRepository {
  final bbx.BbxApiClient _mainnet;
  final bbx.BbxApiClient _testnet;

  static const _pageSize = 50;
  static const _maxPages = 20;

  const BbxApiSepaVirtualPayeeRepository({
    required this._mainnet,
    required this._testnet,
  });

  @override
  Future<Result<SepaVirtualPayeeStatus, RecipientsFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  }) async {
    try {
      final payee = await _api(isTestnet).recipients
          .activateSepaVirtualPayee(recipientId);
      return Ok(_status(payee));
    } on Exception catch (e, st) {
      return Err(
        _failureFrom(
          e,
          st,
          'activate the virtual payee',
          RecipientsUnexpectedFailure.new,
        ),
      );
    }
  }

  @override
  Future<Result<SepaVirtualPayeeStatus?, RecipientsFailure>> findStatus({
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
        for (final payee in result.payees) {
          if (payee.recipientId != recipientId) continue;
          final status = _status(payee);
          if (status == SepaVirtualPayeeStatus.pending) {
            // Listing reads the saved status. Activation is idempotent and
            // refreshes an existing payee from Fiat Republic.
            final refreshed = await recipients.activateSepaVirtualPayee(
              recipientId,
            );
            return Ok(_status(refreshed));
          }
          return Ok(status);
        }
        if (page * _pageSize >= result.totalElements.toInt()) break;
      }
      return const Ok(null);
    } on Exception catch (e, st) {
      return Err(
        _failureFrom(
          e,
          st,
          'read the virtual payee status',
          RecipientsLoadFailure.new,
        ),
      );
    }
  }

  bbx.BbxApiClient _api(bool isTestnet) => isTestnet ? _testnet : _mainnet;

  static SepaVirtualPayeeStatus _status(bbx.SepaVirtualPayee payee) =>
      sepaVirtualPayeeStatusFromApi(payee.virtualPayeeStatus);

  static RecipientsFailure _failureFrom(
    Exception e,
    StackTrace st,
    String operation,
    RecipientsFailure Function([String?]) onApiFailure,
  ) {
    final refusal = exchangeAuthenticationException(e);
    if (refusal != null) {
      return refusal.isUnauthenticated
          ? const RecipientsNotAuthenticatedFailure()
          : onApiFailure('Exchange credential unavailable');
    }
    switch (e) {
      case bbx.BbxApiRpcException() || bbx.BbxApiHttpException():
        final description = _describe(e);
        log.warning('API refused to $operation — $description');
        return onApiFailure(description);
      case DioException(
        type: DioExceptionType.connectionTimeout ||
            DioExceptionType.sendTimeout ||
            DioExceptionType.receiveTimeout ||
            DioExceptionType.connectionError,
      ):
        log.warning('Could not reach the API to $operation: ${e.type}');
        return const RecipientsNetworkFailure();
    }
    log.warning('Failed to $operation', error: e, trace: st);
    return onApiFailure();
  }

  /// The JSON-RPC error message can quote account details: keep the codes.
  static String _describe(Exception e) => switch (e) {
    bbx.BbxApiRpcException(:final code, :final apiCode) =>
      'BbxApiRpcException(code: $code, apiCode: $apiCode)',
    _ => '$e',
  };
}
