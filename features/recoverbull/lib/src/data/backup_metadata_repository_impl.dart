import 'package:convert/convert.dart' show hex;
import 'package:crypto/crypto.dart' show sha256;
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/backup_settings.dart';
import '../domain/entities/backup_status.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/entities/vault_context.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/recoverbull_server_url.dart';
import '../domain/repositories/backup_metadata_repository.dart';
import 'database/recoverbull_database.dart';

final class BackupMetadataRepositoryImpl implements BackupMetadataRepository {
  final RecoverBullDatabase _database;
  final bool durable;
  final DateTime Function() _now;

  BackupMetadataRepositoryImpl(
    this._database, {
    this.durable = true,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  Future<RecoverbullStateData> _state() =>
      _database.select(_database.recoverbullState).getSingle();

  @override
  Future<Result<BackupSettings, RecoverBullFailure>> settings() =>
      _guard(() async {
        final state = await _state();
        final server = Uri.tryParse(state.server);
        if (server == null || !isValidRecoverBullServerUrl(server)) {
          return const Err(VaultStorageFailure());
        }
        return Ok(
          BackupSettings(
            server: server,
            permissionGranted: state.permissionGranted,
            monitoringEnabled: durable && state.monitoringEnabled,
            generation: state.generation,
          ),
        );
      });

  @override
  Future<Result<void, RecoverBullFailure>> importLegacy(
    LegacyBackupSettings settings,
  ) => _guard(
    () => _database.transaction(() async {
      if (!durable) return const Ok(null);
      final state = await _state();
      if (state.legacyImportComplete) return const Ok(null);
      await _database
          .update(_database.recoverbullState)
          .write(
            RecoverbullStateCompanion(
              server: Value(settings.server.toString()),
              permissionGranted: Value(settings.permissionGranted),
              legacyImportComplete: const Value(true),
              generation: Value(state.generation + 1),
            ),
          );
      return const Ok(null);
    }),
  );

  @override
  Future<Result<void, RecoverBullFailure>> changeServer(Uri server) => _guard(
    () => _database.transaction(() async {
      if (!isValidRecoverBullServerUrl(server)) {
        return const Err(VaultInvalidFailure());
      }
      final state = await _state();
      if (state.server == server.toString()) return const Ok(null);
      await _database
          .update(_database.recoverbullState)
          .write(
            RecoverbullStateCompanion(
              server: Value(server.toString()),
              permissionGranted: const Value(false),
              legacyImportComplete: const Value(true),
              generation: Value(state.generation + 1),
            ),
          );
      return const Ok(null);
    }),
  );

  @override
  Future<Result<void, RecoverBullFailure>> acceptServer(Uri displayedServer) =>
      _guard(
        () => _database.transaction(() async {
          final state = await _state();
          if (state.server != displayedServer.toString()) {
            return const Err(VaultContextChangedFailure());
          }
          await _database
              .update(_database.recoverbullState)
              .write(
                RecoverbullStateCompanion(
                  permissionGranted: const Value(true),
                  legacyImportComplete: const Value(true),
                  generation: Value(state.generation + 1),
                ),
              );
          return const Ok(null);
        }),
      );

  @override
  Future<Result<void, RecoverBullFailure>> setMonitoring(bool enabled) =>
      _guard(
        () => _database.transaction(() async {
          if (!durable && enabled) return const Err(VaultStorageFailure());
          final state = await _state();
          await _database
              .update(_database.recoverbullState)
              .write(
                RecoverbullStateCompanion(
                  monitoringEnabled: Value(enabled),
                  legacyImportComplete: const Value(true),
                  generation: Value(state.generation + 1),
                ),
              );
          return const Ok(null);
        }),
      );

  @override
  Future<Result<BackupStatus, RecoverBullFailure>> status(
    VaultContext context,
  ) => _guard(() async {
    if (!durable) return const Ok(BackupStatus());
    final rows =
        await (_database.select(_database.recoverbullBackupStatus)..where(
              (row) =>
                  row.network.equals(context.network.name) &
                  row.fingerprint.equals(context.fingerprint.hex),
            ))
            .get();
    DateTime? storedAt;
    DateTime? verifiedAt;
    for (final row in rows) {
      final stored = row.storedAt;
      final verified = row.verifiedAt;
      if (stored != null && (storedAt == null || stored.isAfter(storedAt))) {
        storedAt = stored;
      }
      if (verified != null &&
          (verifiedAt == null || verified.isAfter(verifiedAt))) {
        verifiedAt = verified;
      }
    }
    return Ok(BackupStatus(storedAt: storedAt, verifiedAt: verifiedAt));
  });

  @override
  Future<Result<void, RecoverBullFailure>> markStored(
    VaultContext context,
    EncryptedVault vault,
  ) => _mark(context, vault, verified: false);

  @override
  Future<Result<void, RecoverBullFailure>> markVerified(
    VaultContext context,
    EncryptedVault vault,
  ) => _mark(context, vault, verified: true);

  Future<Result<void, RecoverBullFailure>> _mark(
    VaultContext context,
    EncryptedVault vault, {
    required bool verified,
  }) => _guard(() async {
    if (!durable) return const Ok(null);
    // The protocol hashes raw identifier bytes, never their hex text.
    final digest = Uint8List.fromList(
      sha256.convert(hex.decode(vault.id)).bytes,
    );
    final at = _now().toUtc();
    await _database
        .into(_database.recoverbullBackupStatus)
        .insertOnConflictUpdate(
          RecoverbullBackupStatusCompanion.insert(
            network: context.network.name,
            fingerprint: context.fingerprint.hex,
            vaultDigest: digest,
            storedAt: verified ? const Value.absent() : Value(at),
            verifiedAt: verified ? Value(at) : const Value.absent(),
          ),
        );
    return const Ok(null);
  });

  Future<Result<T, RecoverBullFailure>> _guard<T>(
    Future<Result<T, RecoverBullFailure>> Function() action,
  ) async {
    try {
      return await action();
    } on Exception {
      return const Err(VaultStorageFailure());
    }
  }
}
