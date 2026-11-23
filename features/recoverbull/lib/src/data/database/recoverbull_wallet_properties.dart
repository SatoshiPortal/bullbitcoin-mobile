import 'package:preferences/preferences.dart'
    show ActiveEnvironmentReader, Environment, PreferencesFailure;
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';

import '../../domain/entities/backup_status.dart';
import '../../domain/entities/vault_context.dart';
import '../../domain/recoverbull_failure.dart';
import 'recoverbull_wallet_backups.dart';

/// The backup facts of each wallet, in the store of its network family.
final class RecoverBullWalletProperties
    implements WalletPropertyStore, InventoryBackupVerification {
  final RecoverBullWalletBackups _backups;
  final RecoverBullWalletBackups _regtestBackups;
  final ActiveEnvironmentReader _environment;
  final Future<Result<BackupStatus, RecoverBullFailure>> Function(VaultContext)
  _vaultStatus;

  const RecoverBullWalletProperties({
    required RecoverBullWalletBackups backups,
    required RecoverBullWalletBackups regtestBackups,
    required ActiveEnvironmentReader environment,
    required Future<Result<BackupStatus, RecoverBullFailure>> Function(
      VaultContext,
    )
    vaultStatus,
  }) : _backups = backups,
       _regtestBackups = regtestBackups,
       _environment = environment,
       _vaultStatus = vaultStatus;

  /// A new wallet starts without any tested backup, even if a deleted wallet
  /// with the same identifier had one.
  @override
  Future<Result<void, Failure>> prepareWallet(
    WalletPropertyDraft wallet,
  ) async => (await _store(wallet.network).write((
    walletId: wallet.id,
    secretFingerprint: wallet.secretFingerprint?.hex,
    encryptedVaultTested: false,
    physicalBackupTested: false,
    latestEncryptedBackup: null,
    latestPhysicalBackup: null,
  ))).mapErr((failure) => failure);

  @override
  Future<Result<bool, SecretFailure>> hasVerifiedBackups(
    List<WalletRegistration> defaults,
  ) async {
    final environment = await _environment.readActiveEnvironment();
    if (environment is! Ok<Environment, PreferencesFailure>) {
      return const Err(FetchSecretFailure());
    }
    final network = environment.value.networkEnv;
    final store = network == NetworkEnv.regtest ? _regtestBackups : _backups;
    VaultContext? vault;
    for (final wallet in defaults.where(
      (wallet) => wallet.network.env == network,
    )) {
      switch (await store.read(wallet.id)) {
        case Err():
          return const Err(FetchSecretFailure());
        case Ok(value: final backup?):
          if (backup.physicalBackupTested || backup.encryptedVaultTested) {
            return const Ok(true);
          }
        case Ok():
          break;
      }
      if ((wallet.network, wallet.secretFingerprint) case (
        final BitcoinNetwork bitcoin,
        final Fingerprint fingerprint,
      )) {
        vault ??= VaultContext(fingerprint: fingerprint, network: bitcoin);
      }
    }
    if (vault == null) return const Ok(false);
    return (await _vaultStatus(vault))
        .map((status) => status.isVerified)
        .mapErr((_) => const FetchSecretFailure());
  }

  RecoverBullWalletBackups _store(Network network) =>
      network.env == NetworkEnv.regtest ? _regtestBackups : _backups;
}
