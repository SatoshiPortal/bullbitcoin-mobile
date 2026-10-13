import 'recoverbull_failure.dart';

// Maps a core failure surfaced while selecting/fetching a vault.
RecoverBullFailure selectVaultFailure(RecoverBullFailure failure) =>
    switch (failure) {
      InvalidVaultFileFailure() => const InvalidVaultFileFormatFailure(),
      _ => const SelectVaultFailure(),
    };

// Maps a core failure surfaced while fetching the vault key from the server.
RecoverBullFailure fetchVaultKeyFailure(RecoverBullFailure failure) =>
    switch (failure) {
      KeyServerInvalidCredentialsFailure() =>
        const InvalidVaultCredentialsFailure(),
      KeyServerRejectedFailure() => const InvalidVaultCredentialsFailure(),
      KeyServerRateLimitedFailure(:final retryIn) => VaultRateLimitedFailure(
        retryIn: retryIn ?? Duration.zero,
      ),
      KeyServerBusyFailure(:final retryIn) => VaultServiceBusyFailure(
        retryIn: retryIn,
      ),
      RecoverBullTemporarilyUnavailableFailure(:final retryIn) =>
        VaultServiceBusyFailure(retryIn: retryIn),
      KeyServerUnavailableFailure() => const VaultKeyFetchFailure(),
      KeyServerTorFailure() => const KeyServerTorFailure(),
      KeyServerOnionUnreachableFailure() =>
        const KeyServerOnionUnreachableFailure(),
      KeyServerServiceRefusedFailure() =>
        const KeyServerServiceRefusedFailure(),
      KeyServerConnectionBudgetFailure() =>
        const KeyServerConnectionBudgetFailure(),
      KeyServerConnectionUnknownFailure() =>
        const KeyServerConnectionUnknownFailure(),
      ExternalTorProxyUnavailableFailure() =>
        const ExternalTorProxyUnavailableFailure(),
      _ => RecoverBullUnexpectedFailure(failure.logMessage),
    };

// Maps a core failure surfaced while storing the vault key during creation.
// Mirrors [fetchVaultKeyFailure] for the shared key-server cases (so a 429
// cooldown or invalid credentials still reach the user) but falls back to the
// creation-specific error instead of the generic unexpected one.
RecoverBullFailure storeVaultKeyFailure(RecoverBullFailure failure) =>
    switch (failure) {
      KeyServerInvalidCredentialsFailure() =>
        const InvalidVaultCredentialsFailure(),
      KeyServerRejectedFailure() => const InvalidVaultCredentialsFailure(),
      KeyServerRateLimitedFailure(:final retryIn) => VaultRateLimitedFailure(
        retryIn: retryIn ?? Duration.zero,
      ),
      KeyServerBusyFailure(:final retryIn) => VaultServiceBusyFailure(
        retryIn: retryIn,
      ),
      RecoverBullTemporarilyUnavailableFailure(:final retryIn) =>
        VaultServiceBusyFailure(retryIn: retryIn),
      KeyServerUnavailableFailure() => const KeyServerConnectionFailure(),
      ExternalTorProxyUnavailableFailure() =>
        const ExternalTorProxyUnavailableFailure(),
      _ => const VaultCreationFailure(),
    };

RecoverBullFailure torConnectionFailure(RecoverBullFailure failure) =>
    switch (failure) {
      ExternalTorProxyUnavailableFailure() =>
        const ExternalTorProxyUnavailableFailure(),
      _ => const TorNotStartedFailure(),
    };
