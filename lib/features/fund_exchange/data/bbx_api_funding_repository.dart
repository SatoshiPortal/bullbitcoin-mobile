import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/fund_exchange/data/funding_datasource_exception.dart';
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
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// [FundingRepository] for one environment on its [BbxApiClient].
class BbxApiFundingRepository implements FundingRepository {
  final BbxApiClient _api;

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
        final link = await _call(
          method,
          () => _api.orders.getCopPaymentLink(
            bankCode: fundingMethod.bankCode,
            amount: fundingMethod.amountCop,
            callbackUrl: ApiServiceConstants.bbAppUrl,
          ),
        );
        return Ok(CopBankTransferFundingDetails(paymentLink: link));
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
      final details = await _call(
        method,
        () => _api.recipients.getUserPaymentProcessorCode(paymentProcessorCode),
      );

      final merged = {...details.element, ...details.extraData}.map(
        (key, value) => MapEntry(key, value is num ? value.toString() : value),
      );
      merged['numTelefono'] ??=
          merged['NUM TELEFONO'] ??
          merged['NUM_TELEFONO'] ??
          merged['PHONE NUMBER'] ??
          merged['phoneNumber'];

      return Ok(
        GetFundingDetailsResponseModel.fromJson(merged)
            .toDomain(method: fundingMethod),
      );
    } on FundingDatasourceException catch (e, st) {
      log.warning('$method failed', error: e, trace: st);
      return Err(_mapException(e));
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
      final list = await _call(
        method,
        () => _api.recipients.listInstitutionCodes(
          countryCode: jurisdiction.code.toLowerCase(),
        ),
      );
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
    } on FundingDatasourceException catch (e, st) {
      log.warning('$method failed', error: e, trace: st);
      return Err(_mapException(e));
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
      // Any answer without an error is a consent.
      await _call(method, _api.users.registerResponsibilityConsent);
      return const Ok(null);
    } on FundingDatasourceException catch (e, st) {
      log.warning('$method failed', error: e, trace: st);
      return Err(switch (e) {
        FundingUnreachableException() => FundExchangeNetworkFailure(
          e.logMessage,
        ),
        _ => FundExchangeConsentRegistrationFailure(e.logMessage),
      });
    } catch (e, st) {
      return Err(
        _unexpected(e, st, method, FundExchangeConsentRegistrationFailure.new),
      );
    }
  }

  /// Runs [request], converting the `bbx_api` errors and the transport
  /// conditions into a [FundingDatasourceException]. An unknown
  /// [DioException], which also carries authentication refusals, is
  /// rethrown.
  Future<T> _call<T>(String method, Future<T> Function() request) async {
    try {
      return await request();
    } on BbxApiRpcException catch (e) {
      throw FundingRpcException(apiCode: e.apiCode, logMessage: e.message);
    } on BbxApiHttpException catch (e) {
      throw FundingNetworkException('HTTP ${e.statusCode}');
    } on BbxApiFormatException catch (e) {
      throw FundingResponseException(e.reason);
    } on DioException catch (e, st) {
      final status = e.response?.statusCode;
      if (status != null) {
        throw FundingNetworkException('HTTP $status');
      }
      if (e.type == DioExceptionType.unknown) {
        rethrow;
      }
      if (e.type == DioExceptionType.badCertificate) {
        log.severe(
          message: 'Exchange API TLS certificate rejected ($method)',
          error: const FundingNetworkException('Bad certificate'),
          trace: st,
        );
      }
      throw switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => FundingUnreachableException(
          'Unreachable: ${e.type.name}',
        ),
        _ => FundingNetworkException('Transport failure: ${e.type.name}'),
      };
    }
  }

  /// The failure for an exception that is not a [FundingDatasourceException].
  /// Errors, including one wrapped in a [DioException], are rethrown.
  FundExchangeFailure _unexpected(
    Object e,
    StackTrace st,
    String method,
    FundExchangeFailure Function(String) failure,
  ) {
    if (e is Error) Error.throwWithStackTrace(e, st);
    if (e case DioException(error: final Error bug, stackTrace: final trace)) {
      Error.throwWithStackTrace(bug, trace);
    }
    final refusal = exchangeAuthenticationException(e);
    if (refusal != null) {
      return refusal.isUnauthenticated
          ? const FundExchangeNotAuthenticatedFailure()
          : const FundExchangeUnexpectedFailure(
              'Exchange credential unavailable',
            );
    }
    final description = e is DioException
        ? 'DioException(${e.type.name})'
        : e.runtimeType.toString();
    log.severe(message: '$method failed', error: description, trace: st);
    return failure(description);
  }

  FundExchangeFailure _mapException(
    FundingDatasourceException e,
  ) => switch (e) {
    FundingRpcException(:final apiCode) => switch (apiCode) {
      'ERR_ORD_PO404' => FundExchangePaymentOptionUnavailableFailure(
        e.logMessage,
      ),
      'ERR_RCP_PO404' => FundExchangeOptionNotPermittedFailure(e.logMessage),
      'ERR_RCP_POSINPE404' => FundExchangeSinpeNotRegisteredFailure(
        e.logMessage,
      ),
      'ERR_ORD_KYC400' => FundExchangeKycIncompleteFailure(e.logMessage),
      'ERR_ORD_COP400' => FundExchangeCopRequestInvalidFailure(e.logMessage),
      'ERR_ORD_CSRCP400' => FundExchangeSepaVirtualPaymentInactiveFailure(
        e.logMessage,
      ),
      'ERR_RCP_400' => FundExchangeRequestInvalidFailure(e.logMessage),
      _ => FundExchangeUnexpectedFailure(e.logMessage),
    },
    FundingUnreachableException() => FundExchangeNetworkFailure(e.logMessage),
    FundingNetworkException() ||
    FundingResponseException() => FundExchangeUnexpectedFailure(e.logMessage),
  };
}
