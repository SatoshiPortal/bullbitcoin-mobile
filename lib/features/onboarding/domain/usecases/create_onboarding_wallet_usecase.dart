import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/secrets.dart' show WalletRegistration;
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:meta/meta.dart';

class CreateOnboardingWalletUsecase {
  final DefaultWalletProvisioning _defaultWallets;

  CreateOnboardingWalletUsecase({required this._defaultWallets});

  @useResult
  Future<Result<List<WalletRegistration>, OnboardingFailure>> execute() async {
    return switch (await _defaultWallets.execute()) {
      Ok(:final value) => Ok(value),
      Err() => const Err(OnboardingWalletSetupFailure()),
    };
  }
}
