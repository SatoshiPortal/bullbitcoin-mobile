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

class OnFetchVaultKey extends RecoverBullEvent {
  const OnFetchVaultKey({required this.vault, required this.password});
  final EncryptedVault vault;
  final String password;
}
