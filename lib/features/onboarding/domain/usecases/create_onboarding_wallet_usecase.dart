import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:meta/meta.dart';

class CreateOnboardingWalletUsecase {
  final CreateDefaultWalletsUsecase _createDefaultWalletsUsecase;

  CreateOnboardingWalletUsecase({required this._createDefaultWalletsUsecase});

  @useResult
  Future<Result<List<Wallet>, OnboardingFailure>> execute() async {
    try {
      final wallets = await _createDefaultWalletsUsecase.execute();
      return Ok(wallets);
    } catch (e, st) {
      log.severe(
        message: 'Onboarding: default wallet creation failed',
        error: e,
        trace: st,
      );
      return const Err(OnboardingWalletSetupFailure());
    }
  }
}
