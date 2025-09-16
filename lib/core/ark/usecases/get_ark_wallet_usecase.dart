import 'package:bb_mobile/core/ark/entities/ark_wallet.dart';
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/core/ark/usecases/fetch_ark_secret_usecase.dart';

class GetArkWalletUsecase {
  final FetchArkSecretUsecase _fetchArkSecretUsecase;

  GetArkWalletUsecase({required FetchArkSecretUsecase fetchArkSecretUsecase})
    : _fetchArkSecretUsecase = fetchArkSecretUsecase;

  Future<ArkWallet> execute() async {
    final arkSecretKey = await _fetchArkSecretUsecase.execute();

    try {
      return await ArkWallet.init(secretKey: arkSecretKey);
    } catch (e) {
      throw ArkError(e.toString());
    }
  }
}
