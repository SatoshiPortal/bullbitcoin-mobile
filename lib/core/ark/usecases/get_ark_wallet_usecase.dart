import 'package:ark_wallet/ark_wallet.dart';
import 'package:bb_mobile/core/ark/ark.dart';
import 'package:bb_mobile/core/ark/usecases/fetch_ark_secret_usecase.dart';
import 'package:bb_mobile/features/ark/errors.dart';

class GetArkWalletUsecase {
  final FetchArkSecretUsecase _fetchArkSecretUsecase;

  GetArkWalletUsecase({required FetchArkSecretUsecase fetchArkSecretUsecase})
    : _fetchArkSecretUsecase = fetchArkSecretUsecase;

  Future<ArkWallet> execute() async {
    final arkSecretKey = await _fetchArkSecretUsecase.execute();

    try {
      final arkWallet = await ArkWallet.init(
        secretKey: arkSecretKey,
        network: Ark.network,
        esplora: Ark.esplora,
        server: Ark.server,
      );
      return arkWallet;
    } catch (e) {
      throw ArkError(e.toString());
    }
  }
}
