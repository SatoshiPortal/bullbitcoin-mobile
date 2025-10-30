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
}

class OnVaultCreation extends RecoverBullEvent {
  const OnVaultCreation({required this.provider, required this.password});
  final VaultProvider provider;
  final String password;
}

class OnVaultFetchKey extends RecoverBullEvent {
  const OnVaultFetchKey({required this.vault, required this.password});
  final EncryptedVault vault;
  final String password;
}

class OnVaultDecryption extends RecoverBullEvent {
  const OnVaultDecryption({required this.vaultKey});
  final String vaultKey;
}

class OnServerCheck extends RecoverBullEvent {
  const OnServerCheck();
}

class OnVaultCheckStatus extends RecoverBullEvent {
  const OnVaultCheckStatus({required this.decryptedVault});
  final DecryptedVault decryptedVault;
}

class OnVaultRecovery extends RecoverBullEvent {
  const OnVaultRecovery();
}
