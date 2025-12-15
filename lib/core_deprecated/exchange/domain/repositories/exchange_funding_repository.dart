import 'package:bb_mobile/core_deprecated/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';

abstract class ExchangeFundingRepository {
  Future<FundingDetails> getExchangeFundingDetails({
    required FundingJurisdiction jurisdiction,
    required FundingMethod fundingMethod,
    int? amount,
  });
}
