import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_wallet_port.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_fee_policy.dart';
import 'package:bb_mobile/features/autosweep/domain/usecases/run_auto_sweep_usecase.dart';
import 'package:bb_mobile/features/autosweep/data/autosweep_wallet_adapter.dart';
import 'package:bb_mobile/features/autosweep/public/autosweep_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:get_it/get_it.dart';

class AutosweepLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<AutosweepFeePolicy>(
      () => const AutosweepFeePolicy(),
    );
    locator.registerLazySingleton<AutosweepWalletPort>(
      () => AutosweepWalletAdapter(
        walletRepository: locator<WalletRepository>(),
        walletAddressRepository: locator<WalletAddressRepository>(),
        liquidWalletRepository: locator<LiquidWalletRepository>(),
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
      ),
    );
    // Deliberately a lazySingleton: the usecase's in-flight wallet id set
    // deduplicates sweeps across concurrent sync triggers, which requires a
    // single shared instance.
    locator.registerLazySingleton<RunAutoSweepUsecase>(
      () => RunAutoSweepUsecase(
        wallets: locator<AutosweepWalletPort>(),
        broadcastLiquid: locator<BroadcastLiquidTransactionUsecase>(),
        broadcastBitcoin: locator<BroadcastBitcoinTransactionUsecase>(),
        getNetworkFees: locator<GetNetworkFeesUsecase>(),
        labelsFacade: locator<LabelsFacade>(),
        feePolicy: locator<AutosweepFeePolicy>(),
      ),
    );
    locator.registerLazySingleton<AutosweepFacade>(
      () => AutosweepFacade(runAutoSweep: locator<RunAutoSweepUsecase>()),
    );
  }
}
