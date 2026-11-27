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

import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';

/// Mounts the authorized catalog and the wallet properties of other owners.
/// The caller owns [admission] and closes it if composition fails.
Future<Result<SecretsInventory, Failure>> openWalletInventory(
  GetIt services, {
  required RuntimeAdmission admission,
  required LegacySource legacy,
  required SessionAuthority authority,
  required File inventoryFile,
  required File signersFile,
  required File syncFile,
  required DatabaseKeys signerKeys,
  required DatabaseKeys syncKeys,
  required RecoverBullCutover recoverBull,
  required RecoverBullCutover regtestRecoverBull,
}) async {
  // RecoverBull opens first: the inventory takes its backup verifier at open,
  // so the verifier exists before the capability does and nothing can bind or
  // replace it afterwards. That one instance is registered as the foreground's
  // only proof of a backup, for protection and for deletion alike.
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
  // One reading of "is this secret backed up" for the whole foreground: the
  // inventory's protection gate and seed deletion judge the same evidence, so
  // a seed can never be deletable while unprotectable, or the reverse.
  final backupVerification = RecoverBullBackupVerification(
    backups: mainBackups,
    regtestBackups: regtestBackups,
  );
  services.registerSingleton(backupVerification);
  final openedInventory = await SecretsInventory.open(
    file: inventoryFile,
    admission: admission,
    authority: authority,
    backupVerification: backupVerification,
  );
  if (openedInventory case Err(:final failure)) return Err(failure);
  final inventory =
      (openedInventory as Ok<SecretsInventory, DatabaseOpenFailure>).value;
  services.registerSingleton(inventory, dispose: (value) => value.close());
  services.registerSingleton<WalletInventory>(inventory);

  final signers = await SignerDevices.open(
    file: signersFile,
    admission: admission,
    keys: signerKeys,
  );
  if (signers case Err(:final failure)) return Err(failure);
  final signerDevices =
      (signers as Ok<SignerDevices, SignerDeviceFailure>).value;
  services.registerSingleton(signerDevices);
  final freshness = await SyncFreshness.open(
    file: syncFile,
    admission: admission,
    keys: syncKeys,
  );
  if (freshness case Err(:final failure)) return Err(failure);
  final syncFreshness = (freshness as Ok<SyncFreshness, SyncFailure>).value;
  services.registerSingleton(syncFreshness);
  services.registerLazySingleton(
    () => RecoverBullWalletProperties(
      backups: mainBackups,
      regtestBackups: regtestBackups,
    ),
  );
  registerWalletProjections(
    services,
    inventory,
    signerDevices,
    syncFreshness,
    mainBackups,
    regtestBackups,
  );
  return Ok(inventory);
}
