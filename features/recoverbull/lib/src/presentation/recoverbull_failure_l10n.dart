import 'package:bull_ui/bull_ui.dart' show BuildContext;

import '../domain/recoverbull_failure.dart';
import '../l10n/context_localizations.dart';

extension RecoverBullFailureL10n on RecoverBullFailure {
  String toTranslated(BuildContext context) => switch (this) {
    RecoverBullStorageFullFailure() => context.loc.recoverbullStorageFull,
    RecoverBullStorageDamagedFailure() => context.loc.recoverbullStorageDamaged,
    RecoverBullJournalFailure() => context.loc.recoverbullJournalUnavailable,
    VaultInvalidFailure() => context.loc.recoverbullErrorInvalidVaultFile,
    VaultWalletMismatchFailure() =>
      context.loc.recoverbullErrorVaultBelongsToAnotherWallet,
    KeyServerFailure(kind: KeyServerFailureKind.credentials) =>
      context.loc.recoverbullErrorInvalidCredentials,
    KeyServerFailure(kind: KeyServerFailureKind.locked) =>
      context.loc.recoverbullLockoutAlert,
    KeyServerFailure() => context.loc.recoverbullErrorConnectionFailed,
    VaultSecretMissingFailure() ||
    VaultKeystoreLockedFailure() ||
    VaultStorageFailure() ||
    VaultUnsupportedSecretFailure() ||
    VaultContextChangedFailure() ||
    VaultWalletMissingFailure() ||
    VaultCancelledFailure() ||
    RecoverBullUnexpectedFailure() => context.loc.recoverbullGenericFailure,
  };
}
