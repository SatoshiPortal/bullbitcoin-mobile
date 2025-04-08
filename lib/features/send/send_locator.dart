import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/send/domain/usecases/confirm_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/locator.dart';

class SendLocator {
  static void setup() => registerUsecases();

  static void registerUsecases() {
    locator.registerLazySingleton<ConfirmBitcoinSendUsecase>(
      () => ConfirmBitcoinSendUsecase(
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
        bitcoinBlockchainRepository: locator<BitcoinBlockchainRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerLazySingleton<DetectBitcoinStringUsecase>(
      () => DetectBitcoinStringUsecase(),
    );
    locator.registerLazySingleton<PrepareBitcoinSendUsecase>(
      () => PrepareBitcoinSendUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
      ),
    );
    locator.registerFactory<SelectBestWalletUsecase>(
      () => SelectBestWalletUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
  }
}
