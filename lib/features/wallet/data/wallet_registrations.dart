import 'package:get_it/get_it.dart';
import 'package:legacy_storage/app_database.dart' show Signer;
import 'package:satoshifier/bip32_derivation.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_error.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart'
    show BackupStatus, RecoverBullFacade, RecoverBullFailure, VaultContext;
import 'package:bull_recoverbull/storage.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:signers/storage.dart';
import 'package:sync/storage.dart';
import 'package:sync/sync.dart'
    show SyncStorageFailure, WalletSnapshotException;

import 'models/wallet_metadata_model.dart';

/// Registers the projection still consumed by the application wallet flows.
void registerWalletProjections(
  GetIt services,
  SecretsInventory inventory,
  SignerDevices signers,
  SyncFreshness freshness,
  RecoverBullWalletBackups mainBackups,
  RecoverBullWalletBackups regtestBackups,
) {
  final registrations = SecretsWalletRegistrations(
    inventory,
    signers,
    freshness,
    mainBackups,
    regtestBackups,
    () => services<ActiveEnvironmentReader>().readActiveEnvironment(),
    (context) => services<RecoverBullFacade>().status(context),
  );
  services.registerSingleton<WalletRegistrations>(registrations);
  services.registerSingleton<InventoryBackupVerification>(registrations);
}

/// Application wallet values still consumed by repositories in the app shell.
abstract interface class WalletRegistrations {
  Future<WalletMetadataModel?> fetch(String id);
  Future<List<WalletMetadataModel>> fetchAll();
  Future<void> insert(WalletMetadataModel metadata);
  Future<void> delete(String id);
  Future<void> recordSyncTime(String id, DateTime time);
}

/// Joins the active inventory to the properties owned by Signers, Sync and
/// RecoverBull. Those properties are never persisted in the legacy catalog.
final class SecretsWalletRegistrations
    implements WalletRegistrations, InventoryBackupVerification {
  final SecretsInventory _inventory;
  final SignerDevices _signers;
  final SyncFreshness _freshness;
  final RecoverBullWalletBackups _backups;
  final RecoverBullWalletBackups _regtestBackups;
  final Future<Result<Environment, PreferencesFailure>> Function()
  _readEnvironment;
  final Future<Result<BackupStatus, RecoverBullFailure>> Function(VaultContext)
  _vaultStatus;

  const SecretsWalletRegistrations(
    this._inventory,
    this._signers,
    this._freshness,
    this._backups,
    this._regtestBackups,
    this._readEnvironment,
    this._vaultStatus,
  );

  @override
  Future<WalletMetadataModel?> fetch(String id) async {
    final row = _value(await _inventory.findWallet(id));
    return row == null ? null : _metadata(row);
  }

  @override
  Future<List<WalletMetadataModel>> fetchAll() async =>
      Future.wait(_value(await _inventory.listWallets()).map(_metadata));

  @override
  Future<void> insert(WalletMetadataModel metadata) async {
    final secret = metadata.signer == Signer.local
        ? metadata.masterFingerprint
        : null;
    final result = await _inventory.registerWallet(
      RegisteredWallet(
        id: metadata.id,
        secretFingerprint: secret,
        masterFingerprint: metadata.masterFingerprint,
        signer: metadata.signer.name,
        network: metadata.networkCode,
        xpub: metadata.xpub,
        externalDescriptor: metadata.externalPublicDescriptor,
        internalDescriptor: metadata.internalPublicDescriptor,
        label: metadata.label,
        birthday: metadata.birthday?.toIso8601String(),
        isDefault: metadata.isDefault,
      ),
      prepareProperties: () async {
        final device = await _signers.write(
          metadata.id,
          metadata.signerDevice?.toEntity(),
        );
        if (device case Err()) return const Err(StoreSecretFailure());
        final freshness = await _freshness.write(metadata.id, null);
        if (freshness case Err()) return const Err(StoreSecretFailure());
        final backup = await _backupStore(metadata.networkCode)
            .write(_backup(metadata));
        return backup.mapErr((_) => const StoreSecretFailure());
      },
    );
    switch (result) {
      case Err(failure: WalletAlreadyRegisteredFailure()):
        throw WalletAlreadyExistsException(metadata.id);
      case Err():
        throw const WalletSnapshotException(SyncStorageFailure());
      case Ok():
        return;
    }
  }

  @override
  Future<void> delete(String id) async {
    _value(await _inventory.removeWallet(id));
  }

  @override
  Future<void> recordSyncTime(String id, DateTime time) async {
    if (_value(await _inventory.findWallet(id)) == null) return;
    _value(await _freshness.write(id, time));
  }

  @override
  Future<Result<bool, SecretFailure>> hasVerifiedBackups(
    List<WalletRegistration> defaults,
  ) async {
    final environment = await _readEnvironment();
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

  RecoverBullWalletBackups _backupStore(String networkCode) =>
      switch (networkCode) {
        'bitcoinRegtest' || 'liquidRegtest' => _regtestBackups,
        _ => _backups,
      };

  static WalletBackupUsage _backup(WalletMetadataModel metadata) => (
    walletId: metadata.id,
    secretFingerprint: metadata.signer == Signer.local
        ? metadata.masterFingerprint
        : null,
    encryptedVaultTested: metadata.isEncryptedVaultTested,
    physicalBackupTested: metadata.isPhysicalBackupTested,
    latestEncryptedBackup: metadata.latestEncryptedBackup,
    latestPhysicalBackup: metadata.latestPhysicalBackup,
  );

  Future<WalletMetadataModel> _metadata(RegisteredWallet row) async {
    final device = _value(await _signers.read(row.id));
    final timestamp = _value(await _freshness.read(row.id));
    final backup = _value(await _backupStore(row.network).read(row.id));
    return WalletMetadataModel(
      id: row.id,
      networkCode: row.network,
      masterFingerprint: row.masterFingerprint,
      xpubFingerprint: _xpubFingerprint(row.xpub),
      isEncryptedVaultTested: backup?.encryptedVaultTested ?? false,
      isPhysicalBackupTested: backup?.physicalBackupTested ?? false,
      latestEncryptedBackup: backup?.latestEncryptedBackup,
      latestPhysicalBackup: backup?.latestPhysicalBackup,
      xpub: row.xpub,
      externalPublicDescriptor: row.externalDescriptor,
      internalPublicDescriptor: row.internalDescriptor,
      signer: Signer.fromName(row.signer),
      isDefault: row.isDefault,
      label: row.label,
      syncedAt: timestamp,
      signerDevice: device?.toSqlite(),
      birthday: DateTime.tryParse(row.birthday ?? ''),
    );
  }

  static String _xpubFingerprint(String xpub) {
    try {
      return Bip32Derivation.getBip32Xpub(xpub).fingerprintHex;
    } on FormatException {
      return '';
    } on ArgumentError {
      return '';
    }
  }

  static T _value<T>(Result<T, Failure> result) => switch (result) {
    Ok(:final value) => value,
    Err() => throw const WalletSnapshotException(SyncStorageFailure()),
  };
}
