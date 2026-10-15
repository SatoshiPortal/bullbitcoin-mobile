import '../domain/recoverbull_failure.dart';
import 'package:flutter/widgets.dart';
import '../l10n/context_localizations.dart';

/// User-facing, localized message for each [RecoverBullFailure]. The `sealed`
/// switch makes a missing message a compile error. Never returns the raw
/// `logMessage`.
extension RecoverBullFailureL10n on RecoverBullFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SelectVaultFailure() => context.loc.recoverbullErrorSelectVault,
    PasswordNotSetFailure() => context.loc.recoverbullErrorPasswordNotSet,
    VaultNotSetFailure() => context.loc.recoverbullErrorVaultNotSet,
    KeyServerConnectionFailure() =>
      context.loc.recoverbullErrorConnectionFailed,
    KeyServerTorFailure() => context.loc.recoverbullErrorTorConnection,
    KeyServerOnionUnreachableFailure() =>
      context.loc.recoverbullErrorOnionUnavailable,
    KeyServerServiceRefusedFailure() =>
      context.loc.recoverbullErrorServiceRefused,
    KeyServerConnectionBudgetFailure() =>
      context.loc.recoverbullErrorConnectionBudget,
    KeyServerConnectionUnknownFailure() =>
      context.loc.recoverbullErrorConnectionUnknown,
    VaultCreationFailure() => context.loc.recoverbullErrorVaultCreationFailed,
    VaultProviderSaveFailure() => context.loc.recoverbullProviderSaveFailed,
    TorNotStartedFailure() => context.loc.recoverbullTorNotStarted,
    ExternalTorProxyUnavailableFailure() =>
      context.recoverBullLabels.torSettingsExternalProxyUnavailableDescription,
    VaultKeyFetchFailure() => context.loc.recoverbullErrorFetchKeyFailed,
    VaultDecryptionFailure() => context.loc.recoverbullErrorDecryptFailed,
    VaultBelongsToAnotherWalletFailure() =>
      context.loc.recoverbullErrorVaultBelongsToAnotherWallet,
    VaultRecoveryFailure() =>
      context.recoverBullLabels.walletSetupErrorTryAgain,
    InvalidVaultCredentialsFailure() =>
      context.loc.recoverbullErrorInvalidCredentials,
    InvalidVaultFileFormatFailure() =>
      context.loc.recoverbullSelectBackupFileNotValidError,
    VaultRateLimitedFailure(:final retryIn) =>
      context.loc.recoverbullErrorRateLimited(_cooldown(context, retryIn)),
    VaultServiceBusyFailure(:final retryIn) =>
      retryIn == null
          ? context.loc.recoverbullErrorServiceBusy
          : context.loc.recoverbullErrorServiceBusyRetryIn(
              _cooldown(context, retryIn),
            ),
    KeyServerInvalidCredentialsFailure() =>
      context.recoverBullLabels.oopsSomethingWentWrong,
    KeyServerRateLimitedFailure() =>
      context.recoverBullLabels.oopsSomethingWentWrong,
    KeyServerBusyFailure(:final retryIn) =>
      retryIn == null
          ? context.loc.recoverbullErrorServiceBusy
          : context.loc.recoverbullErrorServiceBusyRetryIn(
              _cooldown(context, retryIn),
            ),
    KeyServerRejectedFailure() =>
      context.recoverBullLabels.oopsSomethingWentWrong,
    KeyServerUnavailableFailure() =>
      context.recoverBullLabels.oopsSomethingWentWrong,
    KeyServerHealthCheckTimeoutFailure() =>
      context.recoverBullLabels.oopsSomethingWentWrong,
    RecoverBullTemporarilyUnavailableFailure(:final retryIn) =>
      retryIn == null
          ? context.loc.recoverbullErrorServiceBusy
          : context.loc.recoverbullErrorServiceBusyRetryIn(
              _cooldown(context, retryIn),
            ),
    InvalidVaultFileFailure() =>
      context.recoverBullLabels.oopsSomethingWentWrong,
    RecoverBullGoogleDriveFetchFailure() =>
      context.loc.recoverbullGoogleDriveErrorFetchFailed,
    RecoverBullGoogleDriveDeleteFailure() =>
      context.loc.recoverbullGoogleDriveErrorDeleteFailed,
    RecoverBullGoogleDriveExportFailure() =>
      context.loc.recoverbullGoogleDriveErrorExportFailed,
    RecoverBullUnexpectedFailure() =>
      context.recoverBullLabels.oopsSomethingWentWrong,
  };

  String _cooldown(BuildContext context, Duration retryIn) {
    // Floor unknown/elapsed cooldowns (null mapped to zero, or a negative
    // remaining duration) to 1s so the UI never shows "0 seconds" or a
    // negative value.
    final seconds = retryIn.inSeconds < 1 ? 1 : retryIn.inSeconds;
    if (seconds < 60) {
      return seconds == 1
          ? context.loc.durationSecond(seconds.toString())
          : context.loc.durationSeconds(seconds.toString());
    }
    final minutes = seconds ~/ 60;
    final minuteText = minutes == 1
        ? context.loc.durationMinute(minutes.toString())
        : context.loc.durationMinutes(minutes.toString());
    final remainder = seconds % 60;
    if (remainder == 0) return minuteText;
    final secondText = remainder == 1
        ? context.loc.durationSecond(remainder.toString())
        : context.loc.durationSeconds(remainder.toString());
    return context.loc.recoverbullDurationMinutesSeconds(
      minuteText,
      secondText,
    );
  }
}
