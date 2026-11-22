import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/fund_exchange/data/models/get_funding_details_request_params_model.dart';
import 'package:bb_mobile/features/fund_exchange/data/models/get_funding_details_response_model.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/repositories/funding_repository.dart';
import 'package:bbx_api/bbx_api.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// [FundingRepository] for one environment on its [Bbx].
class BbxApiFundingRepository implements FundingRepository {
  final Bbx _api;

  BbxApiFundingRepository({required this._api});

  @override
  @useResult
  Future<Result<FundingDetails, FundExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  }) async {
    final isCop = fundingMethod is CopBankTransfer;
    final method = isCop ? 'getCopPaymentLink' : 'getUserPaymentProcessorCode';

    try {
      if (fundingMethod is CopBankTransfer) {
        final result = await _api.orders.getCopPaymentLink(
          bankCode: fundingMethod.bankCode,
          amount: fundingMethod.amountCop,
          callbackUrl: ApiServiceConstants.bbAppUrl,
        );
        return switch (result) {
          Ok(:final value) => Ok(
            CopBankTransferFundingDetails(paymentLink: value),
          ),
          Err(:final failure) => Err(_failure(failure, method, _refusal)),
        };
      }

      final paymentProcessorCode =
          GetFundingDetailsRequestParamsModel.fromFundingMethod(fundingMethod)
              .paymentProcessorCode;
      if (paymentProcessorCode == null) {
        return const Err(
          FundExchangeUnexpectedFailure(
            'Missing funding payment processor code',
          ),
        );
      }
      final result = await _api.recipients.getUserPaymentProcessorCode(
        paymentProcessorCode,
      );
      return switch (result) {
        Ok(value: final details) => Ok(_details(details, fundingMethod)),
        Err(:final failure) => Err(_failure(failure, method, _refusal)),
      };
    } catch (e, st) {
      return Err(_unexpected(e, st, method, FundExchangeUnexpectedFailure.new));
    }
  }

  @override
  @useResult
  Future<Result<List<FundingInstitution>, FundExchangeFailure>>
  listInstitutions({required FundingJurisdiction jurisdiction}) async {
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
              FundExchangeNoInstitutionsFailure(
                'listInstitutionCodes returned no usable institution',
              ),
            );
          }

          return Ok(institutions);
      }
    } catch (e, st) {
      return Err(_unexpected(e, st, method, FundExchangeUnexpectedFailure.new));
    }
  }

  @override
  @useResult
  Future<Result<void, FundExchangeFailure>>
  registerResponsibilityConsent() async {
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
        _unexpected(e, st, method, FundExchangeConsentRegistrationFailure.new),
      );
    }
  }

  /// The funding details the app reads from [details].
  static FundingDetails _details(
    PaymentProcessorDetails details,
    FundingMethod fundingMethod,
  ) {
    return GetFundingDetailsResponseModel(
      code: details.code,
      userNbr: details.userNbr,
      beneficiaryName: details.beneficiaryName,
      beneficiaryEmail: details.beneficiaryEmail,
      bankAccountDetails: details.bankAccountDetails,
      iban: details.iban,
      swift: details.swift,
      institutionNumber: details.institutionNumber,
      transitNumber: details.transitNumber,
      accountNumber: details.accountNumber,
      routingNumber: details.routingNumber,
      beneficiaryAddress: details.beneficiaryAddress,
      bankAddress: details.bankAddress,
      bankName: details.bankName,
      billerName: details.billerName,
      bic: details.bic,
      bankAccountCountry: details.bankAccountCountry,
      bankCountry: details.bankCountry,
      clabe: details.clabe,
      cedulaJuridica: details.cedulaJuridica,
      cvu: details.cvu,
      numTelefono: details.numTelefono,
    ).toDomain(method: fundingMethod);
  }

  /// The failure for a failed call, logging the reason without the request
  /// or response payload. A missing credential and an unreadable one stay
  /// distinct; [onFailure] maps a network or protocol refusal.
  FundExchangeFailure _failure(
    BbxFailure failure,
    String method,
    FundExchangeFailure Function(BbxFailure failure, String? logMessage)
    onFailure,
  ) {
    switch (failure) {
      case BbxMissingCredentialFailure():
        return const FundExchangeNotAuthenticatedFailure();
      case BbxCredentialUnavailableFailure():
        return const FundExchangeUnexpectedFailure(
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
  static FundExchangeFailure _refusal(BbxFailure failure, String? logMessage) =>
      switch (failure) {
        BbxRpcFailure(:final apiCode) => switch (apiCode) {
          'ERR_ORD_PO404' => FundExchangePaymentOptionUnavailableFailure(
            logMessage,
          ),
          'ERR_RCP_PO404' => FundExchangeOptionNotPermittedFailure(logMessage),
          'ERR_RCP_POSINPE404' => FundExchangeSinpeNotRegisteredFailure(
            logMessage,
          ),
          'ERR_ORD_KYC400' => FundExchangeKycIncompleteFailure(logMessage),
          'ERR_ORD_COP400' => FundExchangeCopRequestInvalidFailure(logMessage),
          'ERR_ORD_CSRCP400' => FundExchangeSepaVirtualPaymentInactiveFailure(
            logMessage,
          ),
          'ERR_RCP_400' => FundExchangeRequestInvalidFailure(logMessage),
          _ => FundExchangeUnexpectedFailure(logMessage),
        },
        BbxTimeoutFailure() ||
        BbxConnectionFailure() => FundExchangeNetworkFailure(logMessage),
        _ => FundExchangeUnexpectedFailure(logMessage),
      };

  /// The failure for the consent call: no funding option maps from it, and
  /// only an unreachable API is a network failure.
  static FundExchangeFailure _consentRefusal(
    BbxFailure failure,
    String? logMessage,
  ) => switch (failure) {
    BbxTimeoutFailure() ||
    BbxConnectionFailure() => FundExchangeNetworkFailure(logMessage),
    _ => FundExchangeConsentRegistrationFailure(logMessage),
  };

  /// The failure for an exception thrown while mapping a response the API
  /// did send. Errors are rethrown.
  FundExchangeFailure _unexpected(
    Object e,
    StackTrace st,
    String method,
    FundExchangeFailure Function(String) failure,
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
