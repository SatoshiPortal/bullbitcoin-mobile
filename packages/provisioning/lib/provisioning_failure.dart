import 'package:primitives/primitives.dart';

sealed class ProvisioningFailure extends Failure {
  const ProvisioningFailure();
}

sealed class DefaultWalletFailure extends ProvisioningFailure {
  const DefaultWalletFailure();
}

final class DefaultWalletAlreadyExistsFailure extends DefaultWalletFailure {
  const DefaultWalletAlreadyExistsFailure();
}

final class DefaultWalletMnemonicRequiredFailure extends DefaultWalletFailure {
  const DefaultWalletMnemonicRequiredFailure();
}

final class DefaultWalletStorageFailure extends DefaultWalletFailure {
  const DefaultWalletStorageFailure();
}

final class DefaultWalletSecretFailure extends DefaultWalletFailure {
  const DefaultWalletSecretFailure();
}

final class DefaultWalletCreationFailure extends DefaultWalletFailure {
  const DefaultWalletCreationFailure();
}

final class DefaultWalletUnexpectedFailure extends DefaultWalletFailure {
  const DefaultWalletUnexpectedFailure();
}

final class DefaultWalletNetworkChangedFailure extends DefaultWalletFailure {
  const DefaultWalletNetworkChangedFailure();
}

final class DefaultWalletRepairFailure extends ProvisioningFailure {
  const DefaultWalletRepairFailure();
}
