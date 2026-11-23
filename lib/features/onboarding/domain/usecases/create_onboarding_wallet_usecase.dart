import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/public/default_wallets_facade.dart';
import 'package:onboarding/onboarding.dart';
import 'package:meta/meta.dart';

class CreateOnboardingWalletUsecase {
  final DefaultWalletsFacade _defaultWallets;

  CreateOnboardingWalletUsecase({required this._defaultWallets});

  @useResult
  Future<Result<void, OnboardingFailure>> execute() async {
    return switch (await _defaultWallets.create()) {
      Ok() => const Ok(null),
      Err() => const Err(OnboardingWalletSetupFailure()),
    };
  }
}
