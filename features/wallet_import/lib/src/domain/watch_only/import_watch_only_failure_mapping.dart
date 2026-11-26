import 'package:provisioning/provisioning.dart';
import 'package:wallet_import/src/domain/import_failure.dart';

/// The import screens distinguish duplicates and invalid keys; every other
/// refusal is a failed import.
ImportWatchOnlyFailure importWatchOnlyFailure(
  WalletProvisioningFailure failure,
) => switch (failure) {
  WalletProvisioningConflictFailure() => const WalletAlreadyExistsFailure(),
  WalletProvisioningInvalidFailure() => const InvalidFormatFailure(),
  WalletProvisioningUnsupportedFailure() ||
  WalletProvisioningSecretFailure() ||
  WalletProvisioningStorageFailure() => const ImportFailedFailure(),
};
