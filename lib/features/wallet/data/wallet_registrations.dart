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
  );
  services.registerSingleton<WalletRegistrations>(registrations);
}

/// Application wallet values still consumed by repositories in the app shell.
abstract interface class WalletRegistrations {
  Future<WalletMetadataModel?> fetch(String id);
  Future<List<WalletMetadataModel>> fetchAll();
}

/// Joins the active inventory to the properties owned by Signers, Sync and
/// RecoverBull. Those properties are never persisted in the legacy catalog.
final class SecretsWalletRegistrations implements WalletRegistrations {
  final SecretsInventory _inventory;
  final SignerDevices _signers;
  final SyncFreshness _freshness;
  final RecoverBullWalletBackups _backups;
  final RecoverBullWalletBackups _regtestBackups;

  const SecretsWalletRegistrations(
    this._inventory,
    this._signers,
    this._freshness,
    this._backups,
    this._regtestBackups,
  );

  @override
  Future<WalletMetadataModel?> fetch(String id) async {
    final row = _value(await _inventory.findWallet(id));
    return row == null ? null : _metadata(row);
  }

  @override
  Future<List<WalletMetadataModel>> fetchAll() async =>
      Future.wait(_value(await _inventory.listWallets()).map(_metadata));

  RecoverBullWalletBackups _backupStore(String networkCode) =>
      switch (networkCode) {
        'bitcoinRegtest' || 'liquidRegtest' => _regtestBackups,
        _ => _backups,
      };

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
