import 'package:bb_mobile/features/fund_exchange/application/ports/exchange_environment_port.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';

// This class delegates recipient-related operations to the appropriate
// gateway based on whether the operation is for testnet or mainnet.
class DelegatingFundingGateway implements FundingGatewayPort {
  final FundingGatewayPort _bullbitcoinFundingGateway;
  final FundingGatewayPort _bullBitcoinTestnetFundingGateway;
  final ExchangeEnvironmentPort _exchangeEnvironment;

  DelegatingFundingGateway({
    required FundingGatewayPort bullbitcoinFundingGateway,
    required FundingGatewayPort bullBitcoinTestnetFundingGateway,
    required ExchangeEnvironmentPort exchangeEnvironment,
  }) : _bullbitcoinFundingGateway = bullbitcoinFundingGateway,
       _bullBitcoinTestnetFundingGateway = bullBitcoinTestnetFundingGateway,
       _exchangeEnvironment = exchangeEnvironment;

  @override
  Future<FundingDetails> getFundingDetails({
    required FundingMethod fundingMethod,
  }) async {
    final isTestnet = await _exchangeEnvironment.isTestnet;
    if (isTestnet) {
      return _bullBitcoinTestnetFundingGateway.getFundingDetails(
        fundingMethod: fundingMethod,
      );
    } else {
      return _bullbitcoinFundingGateway.getFundingDetails(
        fundingMethod: fundingMethod,
      );
    }
  }

  @override
  Future<List<FundingInstitution>> listInstitutions({
    required FundingJurisdiction jurisdiction,
  }) async {
    final isTestnet = await _exchangeEnvironment.isTestnet;
    if (isTestnet) {
      return _bullBitcoinTestnetFundingGateway.listInstitutions(
        jurisdiction: jurisdiction,
      );
    } else {
      return _bullbitcoinFundingGateway.listInstitutions(
        jurisdiction: jurisdiction,
      );
    }
  }
}
