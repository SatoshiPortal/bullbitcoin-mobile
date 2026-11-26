import 'package:primitives/primitives.dart';

import 'src/default_wallet_secret_policy.dart' show DefaultWalletSecretRefusal;

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

/// Creating the default pair of a developer network, or listing the secrets
/// that may back it, was refused or could not complete.
sealed class NetworkWalletSetupFailure extends ProvisioningFailure {
  const NetworkWalletSetupFailure();
}

/// The network, developer mode or superuser right does not allow setup.
final class NetworkWalletSetupContextFailure extends NetworkWalletSetupFailure {
  const NetworkWalletSetupContextFailure();
}

/// The referenced secret cannot back a default wallet.
final class NetworkWalletSetupSecretFailure extends NetworkWalletSetupFailure {
  final DefaultWalletSecretRefusal reason;

  const NetworkWalletSetupSecretFailure(this.reason);
}

/// The wallet catalog could not be read.
final class NetworkWalletSetupStorageFailure extends NetworkWalletSetupFailure {
  const NetworkWalletSetupStorageFailure();
}

/// The requested secret is no longer referenced by the catalog.
final class NetworkWalletSetupReferenceNotFoundFailure
    extends NetworkWalletSetupFailure {
  const NetworkWalletSetupReferenceNotFoundFailure();
}

final class NetworkWalletSetupUnavailableFailure
    extends NetworkWalletSetupFailure {
  const NetworkWalletSetupUnavailableFailure();
}

final class NetworkWalletSetupBackupRequiredFailure
    extends NetworkWalletSetupFailure {
  const NetworkWalletSetupBackupRequiredFailure();
}
