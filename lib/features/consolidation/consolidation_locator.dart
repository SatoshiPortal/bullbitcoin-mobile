import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_banner_cubit.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_cubit.dart';
import 'package:get_it/get_it.dart';

class ConsolidationLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<ConsolidateLiquidWalletUsecase>(
      () => ConsolidateLiquidWalletUsecase(
        liquidWalletRepository: locator<LiquidWalletRepository>(),
        broadcastLiquidTransactionUsecase:
            locator<BroadcastLiquidTransactionUsecase>(),
      ),
    );

    locator.registerFactoryParam<ConsolidationCubit, String, void>(
      (walletId, _) => ConsolidationCubit(
        walletId: walletId,
        consolidateLiquidWalletUsecase:
            locator<ConsolidateLiquidWalletUsecase>(),
        checkLiquidConsolidationUsecase:
            locator<CheckLiquidConsolidationUsecase>(),
      ),
    );

    locator.registerFactoryParam<ConsolidationBannerCubit, String, void>(
      (walletId, _) => ConsolidationBannerCubit(
        checkLiquidConsolidationUsecase:
            locator<CheckLiquidConsolidationUsecase>(),
        walletId: walletId,
      ),
    );
  }
}
