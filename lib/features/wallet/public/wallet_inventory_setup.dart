import 'dart:io';

import 'package:bull_recoverbull/migration.dart'
    show RecoverBullCutover, RecoverBullFailure;
import 'package:bull_recoverbull/storage.dart';
import 'package:get_it/get_it.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:signers/storage.dart';
import 'package:sync/storage.dart';
import 'package:sync/sync.dart' show SyncFailure;

import '../data/wallet_registrations.dart';

/// Mounts the authorized catalog and the wallet properties of other owners.
/// The caller owns [admission] and closes it if composition fails.
Future<Result<SecretsInventory, Failure>> openWalletInventory(
  GetIt services, {
  required RuntimeAdmission admission,
  required LegacySource legacy,
  required File inventoryFile,
  required File signersFile,
  required File syncFile,
  required DatabaseKeys signerKeys,
  required DatabaseKeys syncKeys,
  required RecoverBullCutover recoverBull,
  required RecoverBullCutover regtestRecoverBull,
}) async {
  final openedInventory = await SecretsInventory.open(
    file: inventoryFile,
    admission: admission,
  );
  if (openedInventory case Err(:final failure)) return Err(failure);
  final inventory =
      (openedInventory as Ok<SecretsInventory, DatabaseOpenFailure>).value;
  services.registerSingleton(inventory, dispose: (value) => value.close());

  final signers = await SignerDevices.open(
    file: signersFile,
    admission: admission,
    keys: signerKeys,
  );
  if (signers case Err(:final failure)) return Err(failure);
  final freshness = await SyncFreshness.open(
    file: syncFile,
    admission: admission,
    keys: syncKeys,
  );
  if (freshness case Err(:final failure)) return Err(failure);
  final backups = await RecoverBullWalletBackups.open(
    cutover: recoverBull,
    admission: admission,
    legacy: legacy,
  );
  if (backups case Err(:final failure)) return Err(failure);
  final mainBackups =
      (backups as Ok<RecoverBullWalletBackups, RecoverBullFailure>).value;
  services.registerSingleton(mainBackups, dispose: (value) => value.close());
  final regtest = await RecoverBullWalletBackups.open(
    cutover: regtestRecoverBull,
    admission: admission,
    legacy: legacy,
  );
  if (regtest case Err(:final failure)) return Err(failure);
  final regtestBackups =
      (regtest as Ok<RecoverBullWalletBackups, RecoverBullFailure>).value;
  services.enableRegisteringMultipleInstancesOfOneType();
  services.registerSingleton(
    regtestBackups,
    instanceName: 'regtest',
    dispose: (value) => value.close(),
  );
  final registrations = SecretsWalletRegistrations(
    inventory,
    (signers as Ok<SignerDevices, SignerDeviceFailure>).value,
    (freshness as Ok<SyncFreshness, SyncFailure>).value,
    mainBackups,
    regtestBackups,
  );
  services.registerSingleton<WalletRegistrations>(registrations);
  services.registerSingleton<InventoryBackupVerification>(registrations);
  return Ok(inventory);
}
