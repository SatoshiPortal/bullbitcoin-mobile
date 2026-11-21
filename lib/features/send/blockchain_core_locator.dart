import 'package:bb_mobile/features/send/domain/usecases/verify_signed_tx_usecase.dart';

import 'public/send_facade.dart';

import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/send/data/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:sync/sync.dart' show WalletConnectionPort;
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:get_it/get_it.dart';

class BlockchainLocator {
  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<BitcoinBlockchainRepository>(
      () => BitcoinBlockchainRepository(
        connections: locator<WalletConnectionPort>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<SendFacade>(
      () => SendFacade(
        bitcoin: locator<BroadcastBitcoinTransactionUsecase>().execute,
        liquid: locator<BroadcastLiquidTransactionUsecase>().execute,
        verifySignedTxUsecase: locator<VerifySignedTxUsecase>(),
      ),
    );
    locator.registerFactory<BroadcastBitcoinTransactionUsecase>(
      () => BroadcastBitcoinTransactionUsecase(
        wallet: locator<WalletFacade>(),
        bitcoinBlockchainRepository: locator<BitcoinBlockchainRepository>(),
        settingsRepository: locator<Preferences>(),
        walletUtxoRepository: locator<WalletUtxoRepository>(),
      ),
    );

    locator.registerFactory<BroadcastLiquidTransactionUsecase>(
      () => BroadcastLiquidTransactionUsecase(
        wallet: locator<WalletFacade>(),
        connections: locator<WalletConnectionPort>(),
        settingsRepository: locator<Preferences>(),
      ),
    );
  }
}
