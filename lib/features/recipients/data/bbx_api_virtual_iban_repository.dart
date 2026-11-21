import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';

/// [VirtualIbanRepository] on the `bbx_api` package.
final class BbxApiVirtualIbanRepository implements VirtualIbanRepository {
  final bbx.BbxApiClient _mainnet;
  final bbx.BbxApiClient _testnet;

  static const _optionNotAvailableCode = 'ERR_RCP_PO404';
  static const _euResidencyRequiredCode = 'ERR_RCP_400_001';

  const BbxApiVirtualIbanRepository({
    required this._mainnet,
    required this._testnet,
  });

  @override
  Future<Result<VirtualIban?, RecipientsFailure>> find({
    required bool isTestnet,
  }) async {
    try {
      final iban = await _api(isTestnet).recipients.findVirtualIban();
      return Ok(iban == null ? null : _toDomain(iban));
    } on bbx.BbxApiRpcException catch (e, st) {
      // The API refuses to list virtual IBANs to a user who has none yet and
      // lacks the funding option, so this means "none". Creating it gives
      // the real reason.
      if (e.apiCode == _optionNotAvailableCode) return const Ok(null);
      return Err(_failureFrom(e, st, 'find the virtual IBAN'));
    } on Exception catch (e, st) {
      return Err(_failureFrom(e, st, 'find the virtual IBAN'));
    }
  }

  @override
  Future<Result<VirtualIban, RecipientsFailure>> create({
    required bool isTestnet,
  }) async {
    try {
      return Ok(
        _toDomain(await _api(isTestnet).recipients.createVirtualIban()),
      );
    } on Exception catch (e, st) {
      return Err(_failureFrom(e, st, 'create the virtual IBAN'));
    }
  }

  bbx.BbxApiClient _api(bool isTestnet) => isTestnet ? _testnet : _mainnet;

  static VirtualIban _toDomain(bbx.VirtualIban iban) =>
      VirtualIban.fromBankDetails(
        iban: iban.iban,
        bicCode: iban.bicCode,
        bankAddress: iban.bankAddress,
        ibanCountry: iban.ibanCountry,
      );

  static RecipientsFailure _failureFrom(
    Exception e,
    StackTrace st,
    String operation,
  ) {
    final refusal = exchangeAuthenticationException(e);
    if (refusal != null) {
      return refusal.isUnauthenticated
          ? const RecipientsNotAuthenticatedFailure()
          : const RecipientsUnexpectedFailure(
              'Exchange credential unavailable',
            );
    }
    switch (e) {
      case bbx.BbxApiRpcException(:final apiCode):
        final description = _describe(e);
        log.warning('API refused to $operation — $description');
        return switch (apiCode) {
          _optionNotAvailableCode =>
            const RecipientsVirtualIbanNotAvailableFailure(),
          _euResidencyRequiredCode =>
            const RecipientsEuResidencyRequiredFailure(),
          _ => RecipientsUnexpectedFailure(description),
        };
      case bbx.BbxApiHttpException():
        final description = _describe(e);
        log.warning('API refused to $operation — $description');
        return RecipientsUnexpectedFailure(description);
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
    return const RecipientsUnexpectedFailure();
  }

  /// The JSON-RPC error message can quote account details: keep the codes.
  static String _describe(Exception e) => switch (e) {
    bbx.BbxApiRpcException(:final code, :final apiCode) =>
      'BbxApiRpcException(code: $code, apiCode: $apiCode)',
    _ => '$e',
  };
}
