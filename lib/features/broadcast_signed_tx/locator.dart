import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/locator.dart';

class BroadcastSignedTxLocator {
  static void setup() {
    registerUsecases();
    registerBlocs();
  }

  static void registerUsecases() {
    // Add any use cases here if needed in the future
  }

  static void registerBlocs() {
    locator.registerFactory<BroadcastSignedTxCubit>(
      () => BroadcastSignedTxCubit(
        broadcastBitcoinTransactionUsecase:
            locator<BroadcastBitcoinTransactionUsecase>(),
      ),
    );
  }
}
