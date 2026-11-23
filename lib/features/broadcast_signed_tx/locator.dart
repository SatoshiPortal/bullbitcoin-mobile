import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_imported_bitcoin_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network, NetworkX;
import 'package:electrum/electrum.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:spend/spend.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/application/build_reviewable_transaction_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/verify_broadcast_signed_tx_usecase.dart';
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
        electrum: locator<Electrum>().transactions,
      ),
    );
    locator.registerFactory<VerifyBroadcastSignedTxUsecase>(
      () => VerifyBroadcastSignedTxUsecase(locator<Spend>()),
    );
    locator.registerFactory<BroadcastImportedBitcoinUsecase>(
      () => BroadcastImportedBitcoinUsecase(
        locator<Spend>(),
        locator<ActiveEnvironmentReader>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactoryParam<BroadcastSignedTxCubit, String?, Network?>(
      (unsignedPsbt, network) => BroadcastSignedTxCubit(
        broadcastImportedBitcoin: locator<BroadcastImportedBitcoinUsecase>(),
        verifySignedTxUsecase: locator<VerifyBroadcastSignedTxUsecase>(),
        unsignedPsbt: unsignedPsbt,
        network: switch (network?.shared) {
          final BitcoinNetwork bitcoin => bitcoin,
          _ => null,
        },
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
