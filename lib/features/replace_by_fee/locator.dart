import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:fees/fees.dart';
import 'package:bb_mobile/features/wallet/data/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:get_it/get_it.dart';

class ReplaceByFeeLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<BumpFeeUsecase>(
      () => BumpFeeUsecase(
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
        broadcastBitcoinTransactionUsecase:
            locator<BroadcastBitcoinTransactionUsecase>(),
        fees: locator<Fees>(),
        preferences: locator<Preferences>(),
      ),
    );
  }
}
