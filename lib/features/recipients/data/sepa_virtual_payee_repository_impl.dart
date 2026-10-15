import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/bullbitcoin_api_sepa_virtual_payee_datasource.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';

final class SepaVirtualPayeeRepositoryImpl
    implements SepaVirtualPayeeRepository {
  final BullbitcoinApiSepaVirtualPayeeDatasource _mainnetDatasource;
  final BullbitcoinApiSepaVirtualPayeeDatasource _testnetDatasource;

  static const _pageSize = 50;
  static const _maxPages = 20;

  const SepaVirtualPayeeRepositoryImpl({
    required this._mainnetDatasource,
    required this._testnetDatasource,
  });

  @override
  Future<Result<SepaVirtualPayeeStatus, RecipientsFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  }) async {
    try {
      final model = await _datasource(isTestnet).activate(recipientId);
      return Ok(model.status);
    } on Object catch (e, st) {
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
      final datasource = _datasource(isTestnet);
      for (var page = 1; page <= _maxPages; page++) {
        final result = await datasource.list(page: page, pageSize: _pageSize);
        for (final payee in result.payees) {
          if (payee.recipientId == recipientId) return Ok(payee.status);
        }
        if (page * _pageSize >= result.totalPayees) break;
      }
      return const Ok(null);
    } on Object catch (e, st) {
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

  BullbitcoinApiSepaVirtualPayeeDatasource _datasource(bool isTestnet) =>
      isTestnet ? _testnetDatasource : _mainnetDatasource;

  RecipientsFailure _failureFrom(
    Object e,
    StackTrace st,
    String operation,
    RecipientsFailure Function([String?]) onApiFailure,
  ) {
    if (e is SepaVirtualPayeeApiException) {
      log.warning('API refused to $operation — $e');
      return onApiFailure(e.toString());
    }
    if (e is DioException) {
      final isConnectivity = switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => true,
        _ => false,
      };
      if (isConnectivity) {
        log.warning('Could not reach the API to $operation: ${e.type}');
        return const RecipientsNetworkFailure();
      }
    }
    log.warning('Failed to $operation', error: e, trace: st);
    return onApiFailure();
  }
}
