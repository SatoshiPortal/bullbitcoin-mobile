import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
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
