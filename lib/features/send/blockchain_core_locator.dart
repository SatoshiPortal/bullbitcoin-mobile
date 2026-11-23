import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:sync/sync.dart' show WalletConnectionPort;
import 'package:preferences/preferences.dart';
import 'package:get_it/get_it.dart';

class BlockchainLocator {
  static void registerUsecases(GetIt locator) {
    locator.registerFactory<BroadcastLiquidTransactionUsecase>(
      () => BroadcastLiquidTransactionUsecase(
        wallet: locator<WalletFacade>(),
        connections: locator<WalletConnectionPort>(),
        settingsRepository: locator<Preferences>(),
      ),
    );
  }
}
