import '../domain/entities/drive_file_metadata.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/entities/vault_provider.dart';
import '../domain/recoverbull_failure.dart';

sealed class VaultSelectionState {
  const VaultSelectionState();
}

final class VaultSelectionIdle extends VaultSelectionState {
  const VaultSelectionIdle();
}

final class VaultSelectionOpening extends VaultSelectionState {
  final int attempt;
  final VaultProvider provider;
  const VaultSelectionOpening(this.attempt, this.provider);
}

final class VaultSelectionReading extends VaultSelectionState {
  final int attempt;
  final DriveFileMetadata file;
  const VaultSelectionReading(this.attempt, this.file);
}

final class VaultSelectionSelected extends VaultSelectionState {
  final VaultProvider provider;
  final EncryptedVault vault;
  const VaultSelectionSelected(this.provider, this.vault);
}

final class VaultSelectionCancelled extends VaultSelectionState {
  const VaultSelectionCancelled();
}

final class VaultSelectionEmpty extends VaultSelectionState {
  const VaultSelectionEmpty();
}

final class VaultSelectionFailed extends VaultSelectionState {
  final RecoverBullFailure failure;
  const VaultSelectionFailed(this.failure);
}

sealed class VaultSelectionEvent {
  const VaultSelectionEvent();
}

final class VaultSelectionStarted extends VaultSelectionEvent {
  final int attempt;
  final VaultProvider provider;
  const VaultSelectionStarted(this.attempt, this.provider);
}

final class VaultSelectionListed extends VaultSelectionEvent {
  final int attempt;
  final List<DriveFileMetadata> files;
  const VaultSelectionListed(this.attempt, this.files);
}

final class VaultSelectionOpened extends VaultSelectionEvent {
  final int attempt;
  final EncryptedVault vault;
  const VaultSelectionOpened(this.attempt, this.vault);
}

final class VaultSelectionError extends VaultSelectionEvent {
  final int attempt;
  final RecoverBullFailure failure;
  const VaultSelectionError(this.attempt, this.failure);
}

final class VaultSelectionLeft extends VaultSelectionEvent {
  const VaultSelectionLeft();
}

VaultSelectionState transitionVaultSelection(
  VaultSelectionState state,
  VaultSelectionEvent event,
) {
  if (event is VaultSelectionLeft) return const VaultSelectionIdle();
  if (event is VaultSelectionStarted) {
    return VaultSelectionOpening(event.attempt, event.provider);
  }
  if (state is VaultSelectionOpening &&
      event is VaultSelectionListed &&
      state.attempt == event.attempt &&
      state.provider == VaultProvider.googleDrive) {
    if (event.files.isEmpty) return const VaultSelectionEmpty();
    final latest = event.files.reduce(
      (a, b) => a.createdTime.isAfter(b.createdTime) ? a : b,
    );
    return VaultSelectionReading(event.attempt, latest);
  }
  if (event is VaultSelectionOpened) {
    if (state is VaultSelectionOpening &&
        state.attempt == event.attempt &&
        state.provider != VaultProvider.googleDrive) {
      return VaultSelectionSelected(state.provider, event.vault);
    }
    if (state is VaultSelectionReading && state.attempt == event.attempt) {
      return VaultSelectionSelected(VaultProvider.googleDrive, event.vault);
    }
  }
  if (event is VaultSelectionError &&
      ((state is VaultSelectionOpening && state.attempt == event.attempt) ||
          (state is VaultSelectionReading && state.attempt == event.attempt))) {
    return event.failure is VaultCancelledFailure
        ? const VaultSelectionCancelled()
        : VaultSelectionFailed(event.failure);
  }
  return state;
}
