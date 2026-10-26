part of 'bloc.dart';

sealed class RecoverBullEvent {
  const RecoverBullEvent();
}

class OnVaultProviderSelection extends RecoverBullEvent {
  const OnVaultProviderSelection({required this.provider});
  final VaultProvider provider;
}

class OnVaultSelection extends RecoverBullEvent {
  const OnVaultSelection({required this.provider});
  final VaultProvider provider;
}

class OnVaultPasswordSet extends RecoverBullEvent {
  const OnVaultPasswordSet({required this.password});
  final String password;

  @override
  String toString() => 'OnVaultPasswordSet(<redacted>)';
}

class OnVaultCreation extends RecoverBullEvent {
  const OnVaultCreation({required this.provider, required this.password});
  final VaultProvider provider;
  final String password;

  @override
  String toString() =>
      'OnVaultCreation(provider: $provider, password: <redacted>)';
}

class OnVaultDecryption extends RecoverBullEvent {
  const OnVaultDecryption({required this.vaultKey});
  final String vaultKey;

  @override
  String toString() => 'OnVaultDecryption(<redacted>)';
}

class OnServerCheck extends RecoverBullEvent {
  const OnServerCheck();
}

class OnTorInitialization extends RecoverBullEvent {
  /// Discard a client that is running but stuck, instead of adopting it.
  ///
  /// Only set from an explicit retry: restarting on a rebuild would tear down a
  /// healthy bootstrap in progress.
  final bool restart;

  const OnTorInitialization({this.restart = false});
}

class _OnConnectionUpdated extends RecoverBullEvent {
  final RecoverBullConnection state;
  const _OnConnectionUpdated(this.state);
}

class OnVaultKeyHidden extends RecoverBullEvent {
  const OnVaultKeyHidden();
}

class OnClearError extends RecoverBullEvent {
  const OnClearError();
}

final class OnNewCircuit extends RecoverBullEvent {
  const OnNewCircuit();
}
