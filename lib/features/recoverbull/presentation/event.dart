part of 'bloc.dart';

sealed class RecoverBullEvent {
  const RecoverBullEvent();
}

class OnRecoverBullStarted extends RecoverBullEvent {
  const OnRecoverBullStarted();
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

class OnFetchVaultKey extends RecoverBullEvent {
  const OnFetchVaultKey({required this.vault, required this.password});
  final EncryptedVault vault;
  final String password;
}

class OnVaultKeySet extends RecoverBullEvent {
  const OnVaultKeySet({required this.vaultKey});
  final String vaultKey;
}

class OnCheckKeyServer extends RecoverBullEvent {
  const OnCheckKeyServer();
}

class OnCheckWalletStatus extends RecoverBullEvent {
  const OnCheckWalletStatus({required this.decryptedVault});
  final DecryptedVault decryptedVault;
}

class OnVaultRecovery extends RecoverBullEvent {
  const OnVaultRecovery();
}
