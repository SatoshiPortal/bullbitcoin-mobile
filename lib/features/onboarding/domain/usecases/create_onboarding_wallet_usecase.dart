import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:meta/meta.dart';

class CreateOnboardingWalletUsecase {
  final DefaultWalletsFacade _defaultWallets;

  CreateOnboardingWalletUsecase({required this._defaultWallets});

  @useResult
  Future<Result<List<Wallet>, OnboardingFailure>> execute() async {
    return switch (await _defaultWallets.create()) {
      Ok(:final value) => Ok(value),
      Err() => const Err(OnboardingWalletSetupFailure()),
    };
  }
}
