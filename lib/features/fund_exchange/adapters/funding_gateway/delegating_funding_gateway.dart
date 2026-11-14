import 'package:bb_mobile/features/fund_exchange/application/ports/exchange_environment_port.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

// This class delegates recipient-related operations to the appropriate
// gateway based on whether the operation is for testnet or mainnet.
class DelegatingFundingGateway implements FundingGatewayPort {
  final FundingGatewayPort _bullbitcoinFundingGateway;
  final FundingGatewayPort _bullBitcoinTestnetFundingGateway;
  final ExchangeEnvironmentPort _exchangeEnvironment;

  DelegatingFundingGateway({
    required this._bullbitcoinFundingGateway,
    required this._bullBitcoinTestnetFundingGateway,
    required this._exchangeEnvironment,
  });

  @override
  @useResult
  Future<Result<FundingDetails, FundExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  }) => _withGateway(
    (gateway) => gateway.getFundingDetails(fundingMethod: fundingMethod),
  );

  @override
  @useResult
  Future<Result<List<FundingInstitution>, FundExchangeFailure>>
  listInstitutions({required FundingJurisdiction jurisdiction}) => _withGateway(
    (gateway) => gateway.listInstitutions(jurisdiction: jurisdiction),
  );

  @override
  @useResult
  Future<Result<void, FundExchangeFailure>> registerResponsibilityConsent() =>
      _withGateway((gateway) => gateway.registerResponsibilityConsent());

  Future<Result<T, FundExchangeFailure>> _withGateway<T>(
    Future<Result<T, FundExchangeFailure>> Function(FundingGatewayPort) action,
  ) async {
    try {
      return await action(await _gateway);
    } on UnsupportedExchangeNetworkException {
      return const Err(FundExchangeUnsupportedNetworkFailure());
    }
  }

  Future<FundingGatewayPort> get _gateway async =>
      await _exchangeEnvironment.isTestnet
      ? _bullBitcoinTestnetFundingGateway
      : _bullbitcoinFundingGateway;
}
