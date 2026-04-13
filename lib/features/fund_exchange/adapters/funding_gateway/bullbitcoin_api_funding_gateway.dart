import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/fund_exchange/application/fund_exchange_application_error.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/models/get_funding_details_request_params_model.dart';
import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/models/get_funding_details_response_model.dart';
import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/models/institution_model.dart';
import 'package:dio/dio.dart';

class BullBitcoinApiFundingGateway implements FundingGatewayPort {
  final Dio _authenticatedApiClient;
  final String _ordersPath = '/ak/api-orders';
  final String _recipientsPath = '/ak/api-recipients';
  final String _usersPath = '/ak/api-users';

  BullBitcoinApiFundingGateway({required Dio authenticatedApiClient})
    : _authenticatedApiClient = authenticatedApiClient;

  @override
  Future<FundingDetails> getFundingDetails({
    required FundingMethod fundingMethod,
  }) async {
    final params = GetFundingDetailsRequestParamsModel.fromFundingMethod(
      fundingMethod,
    );

    final resp = await _authenticatedApiClient.post(
      fundingMethod is CopBankTransfer ? _ordersPath : _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': fundingMethod is CopBankTransfer
            ? 'getCopPaymentLink'
            : 'getFundingDetails',
        'params': params.toJson(),
      },
    );

    if (resp.statusCode != 200) {
      final method = fundingMethod is CopBankTransfer
          ? 'getCopPaymentLink'
          : 'getFundingDetails';
      log.severe(
        message: '$method failed: unexpected status code ${resp.statusCode}',
        error: FetchFundingDetailsFailed(
          message: 'Unexpected status code ${resp.statusCode}',
        ),
        trace: StackTrace.current,
      );
      throw const FetchFundingDetailsFailed(message: 'Unexpected status code');
    }

    final error = resp.data['error'];
    if (error != null) {
      final method = fundingMethod is CopBankTransfer
          ? 'getCopPaymentLink'
          : 'getFundingDetails';
      final apiError = error['data']?['apiError'];
      final errorCode = apiError?['code']?.toString() ?? '';
      final errorMessage =
          apiError?['en']?.toString() ??
          error['message']?.toString() ??
          'Unknown API error';
      log.severe(
        message: '$method API error [$errorCode]: $errorMessage',
        error: FetchFundingDetailsFailed(message: errorMessage),
        trace: StackTrace.current,
      );
      throw FetchFundingDetailsFailed(message: errorMessage);
    }

    try {
      final result = resp.data['result'];
      if (fundingMethod is CopBankTransfer) {
        final result = resp.data['result'];
        if (result is! String) {
          throw const FetchFundingDetailsFailed(
            message: 'Invalid payment link format',
          );
        }
        return CopBankTransferFundingDetails(paymentLink: result);
      }
      if (result is! Map<String, dynamic>) {
        throw const FetchFundingDetailsFailed(
          message: 'Missing funding details in response',
        );
      }
      final element = result['element'] as Map<String, dynamic>;
      return GetFundingDetailsResponseModel.fromJson(
        element,
      ).toDomain(method: fundingMethod);
    } catch (e, stackTrace) {
      log.severe(
        message: 'Error parsing funding details response',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<List<FundingInstitution>> listInstitutions({
    required FundingJurisdiction jurisdiction,
  }) async {
    final resp = await _authenticatedApiClient.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'listInstitutionCodes',
        'params': {'countryCode': jurisdiction.code.toLowerCase()},
      },
    );

    if (resp.statusCode != 200) {
      throw const FetchInstitutionsFailed(message: 'Unexpected status code');
    }

    final error = resp.data['error'];
    if (error != null) {
      throw FetchInstitutionsFailed(
        message: error['message']?.toString() ?? 'Unknown API error',
      );
    }

    final result = resp.data['result'];
    if (result is! Map<String, dynamic>) return [];
    final elements = result['elements'] as List<dynamic>?;
    if (elements == null) return [];

    return elements
        .map((e) {
          try {
            return InstitutionModel.fromJson(
              e as Map<String, dynamic>,
            ).toDomain;
          } catch (err, stackTrace) {
            log.severe(
              message: 'Error parsing institution element',
              error: err,
              trace: stackTrace,
            );
            return null;
          }
        })
        .whereType<FundingInstitution>()
        .toList();
  }

  @override
  Future<void> registerResponsibilityConsent() async {
    final resp = await _authenticatedApiClient.post(
      _usersPath,
      data: {
        'id': 1,
        'jsonrpc': '2.0',
        'method': 'registerResponsibilityConsent',
        'params': {},
      },
    );

    if (resp.statusCode != 200) {
      throw const ResponsibilityConsentRegistrationFailed(
        message: 'Unexpected status code',
      );
    }

    final error = resp.data['error'];
    if (error != null) {
      throw ResponsibilityConsentRegistrationFailed(
        message: error['message']?.toString() ?? 'Unknown API error',
      );
    }
  }
}
