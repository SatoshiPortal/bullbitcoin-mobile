import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/virtual_iban.dart';
import '../domain/exchange_environment.dart';
import '../domain/exchange_failure.dart';
import '../domain/repositories/virtual_ibans_repository.dart';

/// Runs a call on a client of [environment]'s session.
typedef RunVirtualIbanOperation =
    Future<Result<T, ExchangeFailure>> Function<T>(
      ExchangeEnvironment environment,
      Future<Result<T, ExchangeFailure>> Function(bbx.Bbx) operation,
    );

/// [VirtualIbansRepository] on the `bbx_api` package.
final class BbxApiVirtualIbansRepository implements VirtualIbansRepository {
  final RunVirtualIbanOperation _run;

  static const _optionNotAvailableCode = 'ERR_RCP_PO404';
  static const _euResidencyRequiredCode = 'ERR_RCP_400_001';

  const BbxApiVirtualIbansRepository({required this._run});

  @override
  Future<Result<VirtualIban?, ExchangeFailure>> find(
    ExchangeEnvironment environment,
  ) => _run(environment, findOn);

  @override
  Future<Result<VirtualIban, ExchangeFailure>> create(
    ExchangeEnvironment environment,
  ) => _run(environment, createOn);

  /// The lookup on a client already opened, for calls that read the virtual
  /// IBAN under the same session as another read.
  static Future<Result<VirtualIban?, ExchangeFailure>> findOn(
    bbx.Bbx api,
  ) async {
    try {
      final result = await api.recipients.findVirtualIban();
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

  static Future<Result<VirtualIban, ExchangeFailure>> createOn(
    bbx.Bbx api,
  ) async {
    try {
      return (await api.recipients.createVirtualIban())
          .map(_toDomain)
          .mapErr(
            (failure) => _failureFrom(failure, 'create the virtual IBAN'),
          );
    } on Exception catch (e, st) {
      return Err(_unexpected(e, st, 'create the virtual IBAN'));
    }
  }

  static VirtualIban _toDomain(bbx.VirtualIban iban) =>
      VirtualIban.fromBankDetails(
        iban: iban.iban,
        bicCode: iban.bicCode,
        bankAddress: iban.bankAddress,
        ibanCountry: iban.ibanCountry,
      );

  static ExchangeFailure _failureFrom(
    bbx.BbxFailure failure,
    String operation,
  ) {
    switch (failure) {
      case bbx.BbxMissingCredentialFailure():
        return const ExchangeNotAuthenticatedFailure();
      case bbx.BbxCredentialUnavailableFailure():
        return const ExchangeCredentialReadFailure();
      case bbx.BbxRpcFailure(:final apiCode):
        final description = '$failure';
        log.warning('API refused to $operation — $description');
        return switch (apiCode) {
          _optionNotAvailableCode =>
            const ExchangeVirtualIbanNotAvailableFailure(),
          _euResidencyRequiredCode =>
            const ExchangeEuResidencyRequiredFailure(),
          _ => ExchangeUnexpectedFailure(description),
        };
      case bbx.BbxHttpFailure():
        final description = '$failure';
        log.warning('API refused to $operation — $description');
        return ExchangeUnexpectedFailure(description);
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
        return const ExchangeUnexpectedFailure();
    }
  }

  /// The failure for an exception thrown while mapping a response the API
  /// did send.
  static ExchangeFailure _unexpected(
    Exception e,
    StackTrace st,
    String operation,
  ) {
    log.warning('Failed to $operation', error: e.runtimeType, trace: st);
    return const ExchangeUnexpectedFailure();
  }

  static String _timeoutName(bbx.BbxTimeoutKind kind) => switch (kind) {
    bbx.BbxTimeoutKind.connect => 'connectionTimeout',
    bbx.BbxTimeoutKind.send => 'sendTimeout',
    bbx.BbxTimeoutKind.receive => 'receiveTimeout',
  };
}
