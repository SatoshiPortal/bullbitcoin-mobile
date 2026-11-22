import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// [VirtualIbanRepository] on the `bbx_api` package.
final class BbxApiVirtualIbanRepository implements VirtualIbanRepository {
  final bbx.Bbx _mainnet;
  final bbx.Bbx _testnet;

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
      final result = await _api(isTestnet).recipients.findVirtualIban();
      return switch (result) {
        Ok(:final value) => Ok(value == null ? null : _toDomain(value)),
        // The API refuses to list virtual IBANs to a user who has none yet
        // and lacks the funding option, so this means "none". Creating it
        // gives the real reason.
        Err(failure: bbx.BbxRpcFailure(apiCode: _optionNotAvailableCode)) =>
          const Ok(null),
        Err(:final failure) => Err(
          _failureFrom(failure, 'find the virtual IBAN'),
        ),
      };
    } on Exception catch (e, st) {
      return Err(_unexpected(e, st, 'find the virtual IBAN'));
    }
  }

  @override
  Future<Result<VirtualIban, RecipientsFailure>> create({
    required bool isTestnet,
  }) async {
    try {
      return (await _api(isTestnet).recipients.createVirtualIban())
          .map(_toDomain)
          .mapErr(
            (failure) => _failureFrom(failure, 'create the virtual IBAN'),
          );
    } on Exception catch (e, st) {
      return Err(_unexpected(e, st, 'create the virtual IBAN'));
    }
  }

  bbx.Bbx _api(bool isTestnet) => isTestnet ? _testnet : _mainnet;

  static VirtualIban _toDomain(bbx.VirtualIban iban) =>
      VirtualIban.fromBankDetails(
        iban: iban.iban,
        bicCode: iban.bicCode,
        bankAddress: iban.bankAddress,
        ibanCountry: iban.ibanCountry,
      );

  static RecipientsFailure _failureFrom(
    bbx.BbxFailure failure,
    String operation,
  ) {
    switch (failure) {
      case bbx.BbxMissingCredentialFailure():
        return const RecipientsNotAuthenticatedFailure();
      case bbx.BbxCredentialUnavailableFailure():
        return const RecipientsUnexpectedFailure(
          'Exchange credential unavailable',
        );
      case bbx.BbxRpcFailure(:final apiCode):
        final description = _describe(failure);
        log.warning('API refused to $operation — $description');
        return switch (apiCode) {
          _optionNotAvailableCode =>
            const RecipientsVirtualIbanNotAvailableFailure(),
          _euResidencyRequiredCode =>
            const RecipientsEuResidencyRequiredFailure(),
          _ => RecipientsUnexpectedFailure(description),
        };
      case bbx.BbxHttpFailure():
        final description = _describe(failure);
        log.warning('API refused to $operation — $description');
        return RecipientsUnexpectedFailure(description);
      case bbx.BbxTimeoutFailure(:final kind):
        log.warning(
          'Could not reach the API to $operation: ${_timeoutName(kind)}',
        );
        return const RecipientsNetworkFailure();
      case bbx.BbxConnectionFailure():
        log.warning('Could not reach the API to $operation: connectionError');
        return const RecipientsNetworkFailure();
      default:
        log.warning(
          'Failed to $operation',
          error: failure,
          trace: StackTrace.current,
        );
        return const RecipientsUnexpectedFailure();
    }
  }

  /// The failure for an exception thrown while mapping a response the API
  /// did send.
  static RecipientsFailure _unexpected(
    Exception e,
    StackTrace st,
    String operation,
  ) {
    log.warning('Failed to $operation', error: e, trace: st);
    return const RecipientsUnexpectedFailure();
  }

  static String _timeoutName(bbx.BbxTimeoutKind kind) => switch (kind) {
    bbx.BbxTimeoutKind.connect => 'connectionTimeout',
    bbx.BbxTimeoutKind.send => 'sendTimeout',
    bbx.BbxTimeoutKind.receive => 'receiveTimeout',
  };

  /// The JSON-RPC error message can quote account details: keep the codes.
  static String _describe(bbx.BbxFailure failure) => switch (failure) {
    bbx.BbxRpcFailure(:final code, :final apiCode) =>
      'BbxRpcFailure(code: $code, apiCode: $apiCode)',
    _ => '$failure',
  };
}
