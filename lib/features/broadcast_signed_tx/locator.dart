import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:get_it/get_it.dart';

class BroadcastSignedTxLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    // Add any use cases here if needed in the future
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactoryParam<BroadcastSignedTxCubit, String?, void>(
      (unsignedPsbt, _) => BroadcastSignedTxCubit(
        broadcastBitcoinTransactionUsecase:
            locator<BroadcastBitcoinTransactionUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        getWalletUtxosUsecase: locator<GetWalletUtxosUsecase>(),
        unsignedPsbt: unsignedPsbt,
      ),
    );
  }
}
