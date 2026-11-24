import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';

import '../onboarding_failure.dart';

class CreateOnboardingWalletUsecase {
  final DefaultWalletProvisioning _defaultWallets;

  CreateOnboardingWalletUsecase({required this._defaultWallets});

  @useResult
  Future<Result<void, OnboardingFailure>> execute() async {
    return switch (await _defaultWallets.execute()) {
      Ok() => const Ok(null),
      Err() => const Err(OnboardingWalletSetupFailure()),
    };
  }
}
