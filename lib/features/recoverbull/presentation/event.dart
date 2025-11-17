part of 'bloc.dart';

sealed class RecoverBullEvent {
  const RecoverBullEvent();
}

class OnVaultProviderSelection extends RecoverBullEvent {
  const OnVaultProviderSelection({required this.provider, this.context});
  final VaultProvider provider;
  final BuildContext? context;
}

class OnVaultSelection extends RecoverBullEvent {
  const OnVaultSelection({required this.provider, this.context});
  final VaultProvider provider;
  final BuildContext? context;
}

class OnVaultPasswordSet extends RecoverBullEvent {
  const OnVaultPasswordSet({required this.password, this.context});
  final String password;
  final BuildContext? context;
}

class OnVaultCreation extends RecoverBullEvent {
  const OnVaultCreation({required this.provider, required this.password, this.context});
  final VaultProvider provider;
  final String password;
  final BuildContext? context;
}

class OnVaultFetchKey extends RecoverBullEvent {
  const OnVaultFetchKey({required this.vault, required this.password, this.context});
  final EncryptedVault vault;
  final String password;
  final BuildContext? context;
}

class OnVaultDecryption extends RecoverBullEvent {
  const OnVaultDecryption({required this.vaultKey, this.context});
  final String vaultKey;
  final BuildContext? context;
}

class OnServerCheck extends RecoverBullEvent {
  const OnServerCheck({this.context});
  final BuildContext? context;
}

class OnVaultCheckStatus extends RecoverBullEvent {
  const OnVaultCheckStatus({required this.decryptedVault, this.context});
  final DecryptedVault decryptedVault;
  final BuildContext? context;
}

class OnVaultRecovery extends RecoverBullEvent {
  const OnVaultRecovery({this.context});
  final BuildContext? context;
}

class OnTorInitialization extends RecoverBullEvent {
  const OnTorInitialization({this.context});
  final BuildContext? context;
}
