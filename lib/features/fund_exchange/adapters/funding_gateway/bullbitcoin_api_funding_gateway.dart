import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/models/get_funding_details_request_params_model.dart';
import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/models/get_funding_details_response_model.dart';
import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/models/institution_model.dart';
import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/funding_datasource_exception.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class BullBitcoinApiFundingGateway implements FundingGatewayPort {
  final Dio _authenticatedApiClient;
  final String _ordersPath = '/ak/api-orders';
  final String _recipientsPath = '/ak/api-recipients';
  final String _usersPath = '/ak/api-users';

  BullBitcoinApiFundingGateway({required this._authenticatedApiClient});

  @override
  @useResult
  Future<Result<FundingDetails, FundExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  }) async {
    final isCop = fundingMethod is CopBankTransfer;
    final method = isCop ? 'getCopPaymentLink' : 'getUserPaymentProcessorCode';

    try {
      final params = GetFundingDetailsRequestParamsModel.fromFundingMethod(
        fundingMethod,
      );
      final result = await _rpc(
        path: isCop ? _ordersPath : _recipientsPath,
        method: method,
        params: params.toJson(),
      );

      if (isCop) {
        if (result is! String) {
          throw const FundingResponseException(
            'getCopPaymentLink returned a non-string payment link',
          );
        }
        return Ok(CopBankTransferFundingDetails(paymentLink: result));
      }

      if (result is! Map<String, dynamic>) {
        throw const FundingResponseException(
          'getUserPaymentProcessorCode returned no funding details',
        );
      }

      final element = (result['element'] as Map<String, dynamic>?) ?? {};
      final ppExtraData =
          (result['ppExtraData'] as Map<String, dynamic>?) ?? {};
      final merged = {...element, ...ppExtraData}.map(
        (key, value) => MapEntry(key, value is num ? value.toString() : value),
      );
      merged['numTelefono'] ??=
          merged['NUM TELEFONO'] ??
          merged['NUM_TELEFONO'] ??
          merged['PHONE NUMBER'] ??
          merged['phoneNumber'];

      return Ok(
        GetFundingDetailsResponseModel.fromJson(
          merged,
        ).toDomain(method: fundingMethod),
      );
    } on FundingDatasourceException catch (e, st) {
      log.warning('$method failed', error: e, trace: st);
      return Err(_mapException(e));
    } catch (e, st) {
      // Genuinely unexpected escape — the raw reason is born here, so it is
      // logged here (Sentry) and the UI shows a generic message.
      log.severe(message: '$method failed', error: e, trace: st);
      return Err(FundExchangeUnexpectedFailure(e.toString()));
    }
  }

  @override
  @useResult
  Future<Result<List<FundingInstitution>, FundExchangeFailure>>
  listInstitutions({required FundingJurisdiction jurisdiction}) async {
    const method = 'listInstitutionCodes';

    try {
      final result = await _rpc(
        path: _recipientsPath,
        method: method,
        params: {'countryCode': jurisdiction.code.toLowerCase()},
      );

      if (result is! Map<String, dynamic>) {
        throw const FundingResponseException(
          'listInstitutionCodes returned no result map',
        );
      }

      final elements = result['elements'] as List<dynamic>?;
      final institutions = (elements ?? const [])
          .map((e) {
            try {
              return InstitutionModel.fromJson(
                e as Map<String, dynamic>,
              ).toDomain;
            } catch (err, st) {
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
        return Err(
          const FundExchangeNoInstitutionsFailure(
            'listInstitutionCodes returned no usable institution',
          ),
        );
      }

      return Ok(institutions);
    } on FundingDatasourceException catch (e, st) {
      log.warning('$method failed', error: e, trace: st);
      return Err(_mapException(e));
    } catch (e, st) {
      log.severe(message: '$method failed', error: e, trace: st);
      return Err(FundExchangeUnexpectedFailure(e.toString()));
    }
  }

  @override
  @useResult
  Future<Result<void, FundExchangeFailure>>
  registerResponsibilityConsent() async {
    const method = 'registerResponsibilityConsent';

    try {
      await _rpc(
        path: _usersPath,
        method: method,
        params: const <String, dynamic>{},
        requireResult: false,
      );
      return const Ok(null);
    } on FundingDatasourceException catch (e, st) {
      log.warning('$method failed', error: e, trace: st);
      return Err(FundExchangeConsentRegistrationFailure(e.logMessage));
    } catch (e, st) {
      log.severe(message: '$method failed', error: e, trace: st);
      return Err(FundExchangeConsentRegistrationFailure(e.toString()));
    }
  }

  /// Performs one JSON-RPC call and returns its `result`, converting every
  /// transport- and protocol-level problem into a [FundingDatasourceException].
  /// Nothing raw escapes past this method.
  Future<dynamic> _rpc({
    required String path,
    required String method,
    required Map<String, dynamic> params,
    bool requireResult = true,
  }) async {
    final response = await _authenticatedApiClient.post(
      path,
      data: {'jsonrpc': '2.0', 'id': '0', 'method': method, 'params': params},
    );

    if (response.statusCode != 200) {
      throw FundingNetworkException('HTTP ${response.statusCode}');
    }

    final body = response.data;
    if (body is! Map) {
      throw const FundingResponseException('Response is not JSON');
    }

    final json = Map<String, dynamic>.from(body);
    final error = json['error'];
    if (error is Map) {
      throw FundingRpcException.fromJson(Map<String, dynamic>.from(error));
    }

    final result = json['result'];
    if (requireResult && result == null) {
      throw const FundingResponseException('Missing RPC result');
    }

    return result;
  }

  /// Maps a datasource exception to the closed failure family. Only the stable
  /// `apiCode` selects the user-facing message; the backend's sentence stays in
  /// `logMessage`, which the presentation extension never reads.
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
    FundingNetworkException() ||
    FundingResponseException() => FundExchangeUnexpectedFailure(e.logMessage),
  };
}
