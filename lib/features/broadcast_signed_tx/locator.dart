import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/transactions/domain/transaction_port.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/application/build_reviewable_transaction_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/transaction_review_cubit.dart';
import 'package:get_it/get_it.dart';

class BroadcastSignedTxLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    locator.registerLazySingleton<BuildReviewableTransactionUsecase>(
      () => BuildReviewableTransactionUsecase(
        transactionPort: locator<TransactionPort>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactoryParam<BroadcastSignedTxCubit, String?, void>(
      (unsignedPsbt, _) => BroadcastSignedTxCubit(
        broadcastBitcoinTransactionUsecase:
            locator<BroadcastBitcoinTransactionUsecase>(),
        unsignedPsbt: unsignedPsbt,
      ),
    );
    locator.registerFactory<TransactionReviewCubit>(
      () => TransactionReviewCubit(
        buildReviewableTransactionUsecase:
            locator<BuildReviewableTransactionUsecase>(),
      ),
    );
  }
}
