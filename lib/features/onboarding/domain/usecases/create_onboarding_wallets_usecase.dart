import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:meta/meta.dart';

class CreateOnboardingWalletsUsecase {
  final CreateDefaultWalletsUsecase _createDefaultWalletsUsecase;

  CreateOnboardingWalletsUsecase(this._createDefaultWalletsUsecase);

  @useResult
  Future<Result<List<Wallet>, OnboardingFailure>> execute({
    List<String>? mnemonicWords,
  }) async {
    try {
      final wallets = mnemonicWords == null
          ? await _createDefaultWalletsUsecase.execute()
          : await _createDefaultWalletsUsecase.execute(
              mnemonicWords: mnemonicWords,
            );
      if (wallets.isEmpty) {
        const failure = OnboardingUnexpectedFailure(
          'No wallets were created or restored',
        );
        log.severe(
          message: failure.logMessage,
          error: failure,
          trace: StackTrace.current,
        );
        return const Err(failure);
      }
      return Ok(wallets);
    } on CreateDefaultWalletsException catch (error, trace) {
      log.severe(
        message: 'createOnboardingWallets failed',
        error: error,
        trace: trace,
      );
      return Err(OnboardingUnexpectedFailure(error.toString()));
    }
  }
}
