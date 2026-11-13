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
    KeyServerFailure(
      kind: KeyServerFailureKind.locked,
      retryAfter: final Duration delay,
    ) =>
      context.loc.recoverbullLockoutWithDuration(
        _lockoutDuration(context, delay),
      ),
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

  String _lockoutDuration(BuildContext context, Duration delay) {
    final loc = context.loc;
    if (delay.inDays >= 1) return loc.recoverbullLockoutDays(delay.inDays);
    if (delay.inHours >= 1) return loc.recoverbullLockoutHours(delay.inHours);
    if (delay.inMinutes >= 1) {
      return loc.recoverbullLockoutMinutes(delay.inMinutes);
    }
    return loc.recoverbullLockoutSeconds(
      delay.inSeconds < 1 ? 1 : delay.inSeconds,
    );
  }
}
