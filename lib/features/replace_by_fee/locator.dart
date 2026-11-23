import 'package:fees/fees.dart';
import 'package:spend/spend.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:get_it/get_it.dart';

class ReplaceByFeeLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<BumpFeeUsecase>(
      () => BumpFeeUsecase(spend: locator<Spend>(), fees: locator<Fees>()),
    );
  }
}
