import 'package:bbx_api/bbx_api.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/funding_details.dart';
import '../domain/entities/funding_institution.dart';
import '../domain/entities/funding_jurisdiction.dart';
import '../domain/entities/funding_method.dart';
import '../domain/exchange_failure.dart';
import 'funding_details_mapper.dart';

final class BbxApiFundingRepository {
  final Bbx _api;
  final Uri _paymentReturnUrl;

  const BbxApiFundingRepository({
    required this._api,
    required this._paymentReturnUrl,
  });

  @useResult
  Future<Result<FundingDetails, ExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  }) async {
    final isCop = fundingMethod is CopBankTransfer;
    final method = isCop ? 'getCopPaymentLink' : 'getUserPaymentProcessorCode';

    try {
      if (fundingMethod is CopBankTransfer) {
        final result = await _api.orders.getCopPaymentLink(
          bankCode: fundingMethod.bankCode,
          amount: fundingMethod.amountCop,
          callbackUrl: _paymentReturnUrl.toString(),
        );
        return switch (result) {
          Ok(:final value) => Ok(
            CopBankTransferFundingDetails(paymentLink: value),
          ),
          Err(:final failure) => Err(_failure(failure, method, _refusal)),
        };
      }

      final paymentProcessorCode = switch (fundingMethod) {
        EmailETransfer() => 'IN_CAD_EMAIL_TRANSFER_APL',
        BankTransferWire() => 'IN_CAD_WIRE_TRANSFER_SCU',
        OnlineBillPayment() => 'IN_CAD_BILL_PAYMENT_APL',
        CanadaPost() => 'IN_CAD_LOADHUB',
        InstantSepa() => 'IN_EUR_CJ_IBAN',
        RegularSepa() => 'IN_EUR_SEPA_DELUBAC',
        SpeiTransfer() => 'IN_MXN_BITSO_CLABE',
        Sinpe() => 'IN_CRC_RDV_SINPE',
        CrIbanCrc() => 'IN_CRC_RDV_IBAN',
        CrIbanUsd() => 'IN_USD_RDV_IBAN',
        ArsBankTransfer() => 'IN_ARS_BITSO',
        CopBankTransfer() => throw StateError(
          'COP handled by its own endpoint',
        ),
      };
      final result = await _api.recipients.getUserPaymentProcessorCode(
        paymentProcessorCode,
      );
      return switch (result) {
        Ok(value: final details) => switch (fundingDetails(
          details,
          fundingMethod,
        )) {
          final value? => Ok(value),
          null => const Err(
            ExchangeUnexpectedFailure('Incomplete funding instructions'),
          ),
        },
        Err(:final failure) => Err(_failure(failure, method, _refusal)),
      };
    } catch (e, st) {
      return Err(_unexpected(e, st, method, ExchangeUnexpectedFailure.new));
    }
  }

  @useResult
  Future<Result<List<FundingInstitution>, ExchangeFailure>> listInstitutions({
    required FundingJurisdiction jurisdiction,
  }) async {
    const method = 'listInstitutionCodes';

    try {
      final result = await _api.recipients.listInstitutionCodes(
        countryCode: jurisdiction.code.toLowerCase(),
      );
      switch (result) {
        case Err(:final failure):
          return Err(_failure(failure, method, _refusal));
        case Ok(value: final list):
          if (list.skippedElements > 0) {
            log.warning(
              'Skipped ${list.skippedElements} unparseable institution elements',
            );
          }

          final institutions = list.institutions
              .map((institution) {
                try {
                  return FundingInstitution.create(
                    code: institution.code,
                    name: institution.name,
                  );
                } on ArgumentError catch (err, st) {
                  log.warning(
                    'Skipped an unparseable institution element',
                    error: err,
                    trace: st,
                  );
                  return null;
                }
              })
              .whereType<FundingInstitution>()
              .toList();

          if (institutions.isEmpty) {
            return const Err(
              ExchangeFundingFailure(
                ExchangeFundingProblem.noInstitutions,
                'listInstitutionCodes returned no usable institution',
              ),
            );
          }

          return Ok(institutions);
      }
    } catch (e, st) {
      return Err(_unexpected(e, st, method, ExchangeUnexpectedFailure.new));
    }
  }

  @useResult
  Future<Result<void, ExchangeFailure>> registerResponsibilityConsent() async {
    const method = 'registerResponsibilityConsent';

    try {
      final result = await _api.users.registerResponsibilityConsent();
      // Any answer without an error is a consent.
      return switch (result) {
        Ok() => const Ok(null),
        Err(:final failure) => Err(_failure(failure, method, _consentRefusal)),
      };
    } catch (e, st) {
      return Err(
        _unexpected(e, st, method, ExchangeConsentRegistrationFailure.new),
      );
    }
  }

  /// The failure for a failed call, logging the reason without the request
  /// or response payload. A missing credential and an unreadable one stay
  /// distinct; [onFailure] maps a network or protocol refusal.
  ExchangeFailure _failure(
    BbxFailure failure,
    String method,
    ExchangeFailure Function(BbxFailure failure, String? logMessage) onFailure,
  ) {
    switch (failure) {
      case BbxMissingCredentialFailure():
        return const ExchangeNotAuthenticatedFailure();
      case BbxCredentialUnavailableFailure():
        return const ExchangeUnexpectedFailure(
          'Exchange credential unavailable',
        );
      case BbxRpcFailure(:final code, :final apiCode):
        // A server sentence can quote an IBAN or the request. Only the two
        // allowlisted codes survive in the app failure and its diagnostics.
        final logMessage = 'BbxRpcFailure(code: $code, apiCode: $apiCode)';
        log.warning(
          '$method failed',
          error: 'FundingRpcException(apiCode: $apiCode)',
          trace: StackTrace.current,
        );
        return onFailure(failure, logMessage);
      case BbxHttpFailure(:final status):
        final logMessage = status == null
            ? 'Transport failure: badResponse'
            : 'HTTP $status';
        log.warning(
          '$method failed',
          error: 'FundingNetworkException($logMessage)',
          trace: StackTrace.current,
        );
        return onFailure(failure, logMessage);
      case BbxResponseFormatFailure(:final reason):
        log.warning(
          '$method failed',
          error: 'FundingResponseException($reason)',
          trace: StackTrace.current,
        );
        return onFailure(failure, reason);
      case BbxTimeoutFailure(:final kind):
        final logMessage = 'Unreachable: ${_timeoutName(kind)}';
        log.warning(
          '$method failed',
          error: 'FundingUnreachableException($logMessage)',
          trace: StackTrace.current,
        );
        return onFailure(failure, logMessage);
      case BbxConnectionFailure():
        const logMessage = 'Unreachable: connectionError';
        log.warning(
          '$method failed',
          error: 'FundingUnreachableException($logMessage)',
          trace: StackTrace.current,
        );
        return onFailure(failure, logMessage);
      case BbxRequestCancelledFailure():
        const logMessage = 'Transport failure: cancel';
        log.warning(
          '$method failed',
          error: 'FundingNetworkException($logMessage)',
          trace: StackTrace.current,
        );
        return onFailure(failure, logMessage);
      case BbxBadCertificateFailure():
        log.severe(
          message: 'Exchange API TLS certificate rejected ($method)',
          error: failure,
          trace: StackTrace.current,
        );
        return onFailure(failure, 'Transport failure: badCertificate');
      case BbxTransformTimeoutFailure():
        const logMessage = 'Transport failure: transformTimeout';
        log.warning(
          '$method failed',
          error: 'FundingNetworkException($logMessage)',
          trace: StackTrace.current,
        );
        return onFailure(failure, logMessage);
      case BbxTransportFailure():
        // The legacy client read an unknown transport error as a
        // DioException of the `unknown` type.
        const logMessage = 'DioException(unknown)';
        log.severe(
          message: '$method failed',
          error: logMessage,
          trace: StackTrace.current,
        );
        return onFailure(failure, logMessage);
      case BbxOrderLimitFailure() || BbxConfidentialSepaInactiveFailure():
        // Order-write refusals: the funding endpoints never produce them, but
        // a failure with no funding meaning is the operation's failure.
        log.warning(
          '$method failed',
          error: failure.runtimeType,
          trace: StackTrace.current,
        );
        return onFailure(failure, null);
    }
  }

  /// The failure for a funding instruction call.
  static ExchangeFailure _refusal(BbxFailure failure, String? logMessage) =>
      switch (failure) {
        BbxRpcFailure(:final apiCode) => switch (apiCode) {
          'ERR_ORD_PO404' => ExchangeFundingFailure(
            ExchangeFundingProblem.paymentOptionUnavailable,
            logMessage,
          ),
          'ERR_RCP_PO404' => ExchangeFundingFailure(
            ExchangeFundingProblem.optionNotPermitted,
            logMessage,
          ),
          'ERR_RCP_POSINPE404' => ExchangeFundingFailure(
            ExchangeFundingProblem.sinpeNotRegistered,
            logMessage,
          ),
          'ERR_ORD_KYC400' => ExchangeFundingFailure(
            ExchangeFundingProblem.kycIncomplete,
            logMessage,
          ),
          'ERR_ORD_COP400' => ExchangeFundingFailure(
            ExchangeFundingProblem.copRequestInvalid,
            logMessage,
          ),
          'ERR_ORD_CSRCP400' => ExchangeFundingFailure(
            ExchangeFundingProblem.sepaVirtualPaymentInactive,
            logMessage,
          ),
          'ERR_RCP_400' => ExchangeFundingFailure(
            ExchangeFundingProblem.requestInvalid,
            logMessage,
          ),
          _ => ExchangeUnexpectedFailure(logMessage),
        },
        BbxTimeoutFailure() ||
        BbxConnectionFailure() => ExchangeNetworkFailure(logMessage),
        _ => ExchangeUnexpectedFailure(logMessage),
      };

  /// The failure for the consent call: no funding option maps from it, and
  /// only an unreachable API is a network failure.
  static ExchangeFailure _consentRefusal(
    BbxFailure failure,
    String? logMessage,
  ) => switch (failure) {
    BbxTimeoutFailure() ||
    BbxConnectionFailure() => ExchangeNetworkFailure(logMessage),
    _ => ExchangeConsentRegistrationFailure(logMessage),
  };

  /// The failure for an exception thrown while mapping a response the API
  /// did send. Errors are rethrown.
  ExchangeFailure _unexpected(
    Object e,
    StackTrace st,
    String method,
    ExchangeFailure Function(String) failure,
  ) {
    if (e is Error) Error.throwWithStackTrace(e, st);
    final description = e.runtimeType.toString();
    log.severe(message: '$method failed', error: description, trace: st);
    return failure(description);
  }

  static String _timeoutName(BbxTimeoutKind kind) => switch (kind) {
    BbxTimeoutKind.connect => 'connectionTimeout',
    BbxTimeoutKind.send => 'sendTimeout',
    BbxTimeoutKind.receive => 'receiveTimeout',
  };
}
