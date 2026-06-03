import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/autosweep/application/autosweep_fee_policy.dart';
import 'package:bb_mobile/features/autosweep/application/run_auto_sweep_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:get_it/get_it.dart';

class AutosweepLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<AutosweepFeePolicy>(
      () => const AutosweepFeePolicy(),
    );
    locator.registerLazySingleton<RunAutoSweepUsecase>(
      () => RunAutoSweepUsecase(
        walletRepository: locator<WalletRepository>(),
        walletAddressRepository: locator<WalletAddressRepository>(),
        liquidWalletRepository: locator<LiquidWalletRepository>(),
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
        broadcastLiquid: locator<BroadcastLiquidTransactionUsecase>(),
        broadcastBitcoin: locator<BroadcastBitcoinTransactionUsecase>(),
        getNetworkFees: locator<GetNetworkFeesUsecase>(),
        labelsFacade: locator<LabelsFacade>(),
        feePolicy: locator<AutosweepFeePolicy>(),
      ),
    );
  }
}
