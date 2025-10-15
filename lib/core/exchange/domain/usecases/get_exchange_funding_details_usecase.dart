import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_funding_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';

class GetExchangeFundingDetailsUsecase {
  final ExchangeFundingRepository _mainnetExchangeFundingRepository;
  final ExchangeFundingRepository _testnetExchangeFundingRepository;
  final SettingsRepository _settingsRepository;

  GetExchangeFundingDetailsUsecase({
    required ExchangeFundingRepository mainnetExchangeFundingRepository,
    required ExchangeFundingRepository testnetExchangeFundingRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeFundingRepository = mainnetExchangeFundingRepository,
       _testnetExchangeFundingRepository = testnetExchangeFundingRepository,
       _settingsRepository = settingsRepository;

  Future<FundingDetails> execute({
    required FundingJurisdiction jurisdiction,
    required FundingMethod fundingMethod,
    int? amount,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeFundingRepository
              : _mainnetExchangeFundingRepository;

      final fundingDetails = await repo.getExchangeFundingDetails(
        jurisdiction: jurisdiction,
        fundingMethod: fundingMethod,
        amount: amount,
      );

      return fundingDetails;
    } catch (e) {
      throw GetExchangeFundingDetailsException('$e');
    }
  }
}

class GetExchangeFundingDetailsException extends BullException {
  GetExchangeFundingDetailsException(super.message);
}
