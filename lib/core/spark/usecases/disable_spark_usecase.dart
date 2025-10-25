import 'package:bb_mobile/core/spark/usecases/get_spark_wallet_usecase.dart';

class DisableSparkUsecase {
  final GetSparkWalletUsecase _getSparkWalletUsecase;

  DisableSparkUsecase({required GetSparkWalletUsecase getSparkWalletUsecase})
    : _getSparkWalletUsecase = getSparkWalletUsecase;

  Future<void> execute() async {
    final wallet = await _getSparkWalletUsecase.execute();
    if (wallet != null) {
      await wallet.disconnect();
      _getSparkWalletUsecase.clearCache();
    }
  }
}
