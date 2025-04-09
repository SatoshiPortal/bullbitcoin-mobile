import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/liquid_wallet_repository.dart';
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
        liquidWalletRepository: locator<LiquidWalletRepository>(),
        liquidBlockchainRepository: locator<LiquidBlockchainRepository>(),
      ),
    );
    locator.registerLazySingleton<DetectBitcoinStringUsecase>(
      () => DetectBitcoinStringUsecase(),
    );
    locator.registerLazySingleton<PrepareBitcoinSendUsecase>(
      () => PrepareBitcoinSendUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
        liquidWalletRepository: locator<LiquidWalletRepository>(),
      ),
    );
    locator.registerFactory<SelectBestWalletUsecase>(
      () => SelectBestWalletUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
  }
}
