import 'package:bb_mobile/features/fund_exchange/domain/exchange_environment_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/repositories/funding_repository.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

// This class delegates recipient-related operations to the appropriate
// repository based on whether the operation is for testnet or mainnet.
class FundingRepositoryImpl implements FundingRepository {
  final FundingRepository _bullbitcoinFundingRepository;
  final FundingRepository _bullBitcoinTestnetFundingRepository;
  final ExchangeEnvironmentPort _exchangeEnvironment;

  FundingRepositoryImpl({
    required this._bullbitcoinFundingRepository,
    required this._bullBitcoinTestnetFundingRepository,
    required this._exchangeEnvironment,
  });

  @override
  @useResult
  Future<Result<FundingDetails, FundExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  }) async {
    final repository = await _repository;
    return repository.getFundingDetails(fundingMethod: fundingMethod);
  }

  @override
  @useResult
  Future<Result<List<FundingInstitution>, FundExchangeFailure>>
  listInstitutions({required FundingJurisdiction jurisdiction}) async {
    final repository = await _repository;
    return repository.listInstitutions(jurisdiction: jurisdiction);
  }

  @override
  @useResult
  Future<Result<void, FundExchangeFailure>>
  registerResponsibilityConsent() async {
    final repository = await _repository;
    return repository.registerResponsibilityConsent();
  }

  Future<FundingRepository> get _repository async =>
      await _exchangeEnvironment.isTestnet
      ? _bullBitcoinTestnetFundingRepository
      : _bullbitcoinFundingRepository;
}
