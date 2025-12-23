import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:get_it/get_it.dart';

class ReplaceByFeeLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<BumpFeeUsecase>(
      () => BumpFeeUsecase(
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
      ),
    );
  }
}
