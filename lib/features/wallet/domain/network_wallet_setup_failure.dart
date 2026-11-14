import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/default_wallet_secret_policy.dart';
import 'package:primitives/primitives.dart';

sealed class NetworkWalletSetupFailure extends Failure {
  const NetworkWalletSetupFailure();
}

final class NetworkWalletSetupContextFailure extends NetworkWalletSetupFailure {
  const NetworkWalletSetupContextFailure();
}

final class NetworkWalletSetupSecretFailure extends NetworkWalletSetupFailure {
  final DefaultWalletSecretRefusal reason;

  const NetworkWalletSetupSecretFailure(this.reason);
}

final class NetworkWalletSetupReadFailure extends NetworkWalletSetupFailure {
  final WalletFailure failure;

  const NetworkWalletSetupReadFailure(this.failure);
}

final class NetworkWalletSetupUnavailableFailure
    extends NetworkWalletSetupFailure {
  const NetworkWalletSetupUnavailableFailure();
}
