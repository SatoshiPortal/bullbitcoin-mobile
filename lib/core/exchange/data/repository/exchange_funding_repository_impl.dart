import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/funding_details_request_params_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_funding_repository.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';

class ExchangeFundingRepositoryImpl implements ExchangeFundingRepository {
  final BullbitcoinApiDatasource _apiDatasource;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;

  ExchangeFundingRepositoryImpl({
    required BullbitcoinApiDatasource apiDatasource,
    required BullbitcoinApiKeyDatasource apiKeyDatasource,
    required bool isTestnet,
  }) : _apiDatasource = apiDatasource,
       _apiKeyDatasource = apiKeyDatasource,
       _isTestnet = isTestnet;

  @override
  Future<FundingDetails> getExchangeFundingDetails({
    required FundingJurisdiction jurisdiction,
    required FundingMethod fundingMethod,
    int? amount,
  }) async {
    try {
      final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);

      if (apiKey == null) {
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }
      if (!apiKey.isActive) {
        throw ApiKeyException(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      final fundingDetailsRequestParams = FundingDetailsRequestParamsModel(
        jurisdiction: jurisdiction.code,
        paymentMethod: switch (fundingMethod) {
          FundingMethod.emailETransfer => 'eTransfer',
          FundingMethod.bankTransferWire => 'wire',
          FundingMethod.onlineBillPayment => 'billPayment',
          FundingMethod.canadaPost => 'canadaPost',
          FundingMethod.sepaTransfer => 'instantSepa',
          FundingMethod.speiTransfer => 'spei',
          FundingMethod.crIbanCrc => 'CRIbanCRC',
          FundingMethod.crIbanUsd => 'CRIbanUSD',
        },
        amount: amount,
      );

      final fundingDetailsModel = await _apiDatasource.getFundingDetails(
        apiKey: apiKey.key,
        fundingDetailsRequestParams: fundingDetailsRequestParams,
      );

      return fundingDetailsModel.toEntity(method: fundingMethod);
    } catch (e) {
      // Log the error or handle it as needed
      throw Exception('Failed to fetch funding details: $e');
    }
  }
}
