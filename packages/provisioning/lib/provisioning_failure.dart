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

/// The view is protected by a PIN and the new seed has no tested backup, so it
/// is not attached. Nothing was created.
final class DefaultWalletBackupRequiredFailure extends DefaultWalletFailure {
  const DefaultWalletBackupRequiredFailure();
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

/// Creating or importing one account failed.
sealed class WalletProvisioningFailure extends ProvisioningFailure {
  const WalletProvisioningFailure();
}

/// The account, or the default account of its network, already exists.
final class WalletProvisioningConflictFailure
    extends WalletProvisioningFailure {
  const WalletProvisioningConflictFailure();
}

/// The key material does not describe a valid account.
final class WalletProvisioningInvalidFailure extends WalletProvisioningFailure {
  const WalletProvisioningInvalidFailure();
}

/// The network or script type cannot be created.
final class WalletProvisioningUnsupportedFailure
    extends WalletProvisioningFailure {
  const WalletProvisioningUnsupportedFailure();
}

/// The secret could not derive the account's public material.
final class WalletProvisioningSecretFailure extends WalletProvisioningFailure {
  const WalletProvisioningSecretFailure();
}

/// The view is protected by a PIN and the account's seed has no tested backup:
/// no seed without a backup is attached to a protected view (D97).
final class WalletProvisioningBackupRequiredFailure
    extends WalletProvisioningFailure {
  const WalletProvisioningBackupRequiredFailure();
}

/// The inventory, a property owner or the native store refused the write.
final class WalletProvisioningStorageFailure extends WalletProvisioningFailure {
  const WalletProvisioningStorageFailure();
}
