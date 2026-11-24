import 'dart:io';

import 'package:drift/drift.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:legacy_storage/wallet_column_projection.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart'
    show WalletPropertyDraft, WalletPropertyStore;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../signer_device.dart';
import 'signer_devices.drift.dart';

@DataClassName('WalletSignerDeviceRow')
class WalletSignerDevices extends Table {
  TextColumn get walletId => text()();
  TextColumn get signerDevice => text().nullable()();

  @override
  Set<Column> get primaryKey => {walletId};
}

class LegacyImportReceipts extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [WalletSignerDevices, LegacyImportReceipts])
final class SignerDevicesDatabase extends $SignerDevicesDatabase {
  SignerDevicesDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() => migrator.createAll()),
  );
}

LegacyImportParticipant signersWalletMetadataImport({
  required File file,
  required DatabaseKeys keys,
}) => _projection(file, keys);

WalletColumnProjection<SignerDevicesDatabase> _projection(
  File file,
  DatabaseKeys keys,
) => WalletColumnProjection(
  ownerId: 'signers',
  file: file,
  column: 'signer_device',
  destinationTable: 'wallet_signer_devices',
  create: SignerDevicesDatabase.new,
  openExecutor: ({required existing}) async =>
      (await keys.open(
        name: 'main',
        file: file,
        existingSchemaVersion: existing ? 1 : null,
      )).mapErr(
        (failure) => switch (failure) {
          DatabaseNotReady() ||
          DatabaseKeyUnavailable(
            reason: DatabaseKeyProblem.locked,
          ) => const LegacyImportDeferred(),
          _ => const LegacyImportUnavailable(),
        },
      ),
);

final class SignerDevices implements WalletPropertyStore {
  final SignerDevicesDatabase _database;

  const SignerDevices._(this._database);

  @useResult
  static Future<Result<SignerDevices, SignerDeviceFailure>> open({
    required File file,
    required RuntimeAdmission admission,
    required DatabaseKeys keys,
  }) async =>
      (await _projection(file, keys).openRuntime(admission))
          .map(SignerDevices._)
          .mapErr((_) => const SignerDeviceUnavailable());

  /// Records the device chosen at import, or clears a stale association.
  @override
  Future<Result<void, Failure>> prepareWallet(
    WalletPropertyDraft wallet,
  ) async {
    final name = wallet.signerDevice;
    final device = name == null
        ? null
        : SignerDevice.values
              .where((device) => device.name == name)
              .firstOrNull;
    if (name != null && device == null) {
      return const Err(SignerDeviceUnavailable());
    }
    return (await write(wallet.id, device)).mapErr((failure) => failure);
  }

  @useResult
  Future<Result<SignerDevice?, SignerDeviceFailure>> read(
    String walletId,
  ) async {
    try {
      final row = await (_database.select(
        _database.walletSignerDevices,
      )..where((row) => row.walletId.equals(walletId))).getSingleOrNull();
      final name = row?.signerDevice;
      if (name == null) return const Ok(null);
      for (final device in SignerDevice.values) {
        if (device.name == name) return Ok(device);
      }
      return const Err(SignerDeviceUnavailable());
    } on SqliteException {
      return const Err(SignerDeviceUnavailable());
    }
  }

  @useResult
  Future<Result<void, SignerDeviceFailure>> write(
    String walletId,
    SignerDevice? value,
  ) async {
    try {
      await _database
          .into(_database.walletSignerDevices)
          .insertOnConflictUpdate(
            WalletSignerDevicesCompanion.insert(
              walletId: walletId,
              signerDevice: Value(value?.name),
            ),
          );
      return const Ok(null);
    } on SqliteException {
      return const Err(SignerDeviceUnavailable());
    }
  }
}

sealed class SignerDeviceFailure extends Failure {
  const SignerDeviceFailure();
}

final class SignerDeviceUnavailable extends SignerDeviceFailure {
  const SignerDeviceUnavailable();
}
