import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/datasources/bullbitcoin_api_virtual_iban_datasource.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';

final class VirtualIbanRepositoryImpl implements VirtualIbanRepository {
  final BullbitcoinApiVirtualIbanDatasource _mainnetDatasource;
  final BullbitcoinApiVirtualIbanDatasource _testnetDatasource;

  static const _optionNotAvailableCode = 'ERR_RCP_PO404';
  static const _euResidencyRequiredCode = 'ERR_RCP_400_001';

  const VirtualIbanRepositoryImpl({
    required this._mainnetDatasource,
    required this._testnetDatasource,
  });

  @override
  Future<Result<VirtualIban?, RecipientsFailure>> find({
    required bool isTestnet,
  }) async {
    try {
      final model = await _datasource(isTestnet).find();
      return Ok(model?.toDomain);
    } on VirtualIbanApiException catch (e, st) {
      // The API refuses to list virtual IBANs to a user who has none yet and
      // lacks the funding option, so this means "none". Creating it gives
      // the real reason.
      if (e.code == _optionNotAvailableCode) return const Ok(null);
      return Err(_failureFrom(e, st, 'find the virtual IBAN'));
    } on Object catch (e, st) {
      return Err(_failureFrom(e, st, 'find the virtual IBAN'));
    }
  }

  @override
  Future<Result<VirtualIban, RecipientsFailure>> create({
    required bool isTestnet,
  }) async {
    try {
      final model = await _datasource(isTestnet).create();
      return Ok(model.toDomain);
    } on Object catch (e, st) {
      return Err(_failureFrom(e, st, 'create the virtual IBAN'));
    }
  }

  BullbitcoinApiVirtualIbanDatasource _datasource(bool isTestnet) =>
      isTestnet ? _testnetDatasource : _mainnetDatasource;

  RecipientsFailure _failureFrom(Object e, StackTrace st, String operation) {
    if (e is VirtualIbanApiException) {
      log.warning('API refused to $operation — $e');
      return switch (e.code) {
        _optionNotAvailableCode =>
          const RecipientsVirtualIbanNotAvailableFailure(),
        _euResidencyRequiredCode =>
          const RecipientsEuResidencyRequiredFailure(),
        _ => RecipientsUnexpectedFailure(e.toString()),
      };
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
    return const RecipientsUnexpectedFailure();
  }
}
