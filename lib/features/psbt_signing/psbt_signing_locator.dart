import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/psbt_signing/domain/usecases/review_psbt_usecase.dart';
import 'package:bb_mobile/features/psbt_signing/domain/usecases/sign_external_psbt_usecase.dart';
import 'package:bb_mobile/features/psbt_signing/presentation/psbt_signing_cubit.dart';
import 'package:get_it/get_it.dart';

class PsbtSigningLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<ReviewPsbtUsecase>(
      () => ReviewPsbtUsecase(
        getWalletUsecase: locator<GetWalletUsecase>(),
        bitcoinSigningPort: locator<BitcoinSigningPort>(),
      ),
    );
    locator.registerFactory<SignExternalPsbtUsecase>(
      () => SignExternalPsbtUsecase(locator<BitcoinSigningPort>()),
    );
    locator.registerFactoryParam<PsbtSigningCubit, String, void>(
      (walletId, _) => PsbtSigningCubit(
        walletId: walletId,
        reviewPsbtUsecase: locator<ReviewPsbtUsecase>(),
        signExternalPsbtUsecase: locator<SignExternalPsbtUsecase>(),
      ),
    );
  }
}
