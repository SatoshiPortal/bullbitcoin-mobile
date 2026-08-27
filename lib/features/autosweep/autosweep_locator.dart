import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_preferences_usecase.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_fee_policy.dart';
import 'package:bb_mobile/features/autosweep/domain/usecases/run_auto_sweep_usecase.dart';
import 'package:bb_mobile/features/autosweep/public/autosweep_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:get_it/get_it.dart';

class AutosweepLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<AutosweepFeePolicy>(
      () => const AutosweepFeePolicy(),
    );
    // Deliberately a lazySingleton: the usecase's in-flight wallet id set
    // deduplicates sweeps across concurrent sync triggers, which requires a
    // single shared instance.
    locator.registerLazySingleton<RunAutoSweepUsecase>(
      () => RunAutoSweepUsecase(
        locator<WalletRepository>(),
        locator<WalletAddressRepository>(),
        locator<LiquidWalletRepository>(),
        locator<BitcoinWalletRepository>(),
        locator<BroadcastLiquidTransactionUsecase>(),
        locator<BroadcastBitcoinTransactionUsecase>(),
        locator<GetNetworkFeesUsecase>(),
        locator<LabelsFacade>(),
        locator<AutosweepFeePolicy>(),
        locator<GetWalletPreferencesUsecase>().execute,
      ),
    );
    locator.registerLazySingleton<AutosweepFacade>(
      () => AutosweepFacade(runAutoSweep: locator<RunAutoSweepUsecase>()),
    );
  }
}
