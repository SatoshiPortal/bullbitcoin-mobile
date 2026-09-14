import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/vault_descriptor_publication.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

/// The durable half of descriptor publication: the destination the person
/// chose, the exact bytes owed to it, and what happened last.
///
/// Publication state is not a backed-up fact, so a write here never touches the
/// backup revision: restoring a metadata backup must not make another device's
/// upload look finished.
final class VaultDescriptorPublicationRepository {
  final SqliteDatabase _database;
  final DateTime Function() _now;

  VaultDescriptorPublicationRepository(
    this._database, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Every destination row this vault has, in destination order.
  @useResult
  Future<Result<List<VaultDescriptorPublication>, BullVaultFailure>> load(
    String walletId,
  ) => _read('load', () async {
    final rows =
        await (_database.select(_database.vaultDescriptorPublications)
              ..where((row) => row.walletId.equals(walletId))
              ..orderBy([(row) => OrderingTerm.asc(row.destination)]))
            .get();
    return rows.map(_map).nonNulls.toList();
  });

  /// Records the person's choice, and nothing else. Turning a destination off
  /// keeps the artifact: it is evidence of what was already sent.
  @useResult
  Future<Result<void, BullVaultFailure>> setEnabled({
    required String walletId,
    required VaultBackupDestination destination,
    required bool enabled,
  }) => _write('set enabled', () async {
    await _upsert(
      walletId: walletId,
      destination: destination,
      enabled: Value(enabled),
    );
  });

  /// Stores the bytes a destination owes, replacing whatever was there.
  ///
  /// This is the only way an artifact changes. A renewal is a different vault
  /// record with its own row, so nothing here can quietly re-seal a descriptor
  /// that already has a published event.
  @useResult
  Future<Result<void, BullVaultFailure>> prepare({
    required String walletId,
    required VaultBackupDestination destination,
    required Uint8List artifact,
  }) => _write('prepare', () async {
    await _upsert(
      walletId: walletId,
      destination: destination,
      artifact: Value(artifact),
      artifactSha256: Value(sha256.convert(artifact).toString()),
      state: const Value(VaultPublicationState.pending),
      attempts: const Value(0),
    );
  });

  /// A destination acknowledged the artifact. Not proof it can be read back.
  @useResult
  Future<Result<void, BullVaultFailure>> markSent({
    required String walletId,
    required VaultBackupDestination destination,
  }) => _mark(walletId, destination, VaultPublicationState.sent);

  /// A destination refused the artifact or could not be reached. The artifact
  /// stays, so a retry resends it rather than sealing a second one.
  @useResult
  Future<Result<void, BullVaultFailure>> markFailed({
    required String walletId,
    required VaultBackupDestination destination,
  }) => _mark(walletId, destination, VaultPublicationState.failed);

  /// The artifact was read back from the destination and matched. A read-back
  /// is not a send, so it leaves the attempt count alone.
  @useResult
  Future<Result<void, BullVaultFailure>> markVerified({
    required String walletId,
    required VaultBackupDestination destination,
  }) => _mark(
    walletId,
    destination,
    VaultPublicationState.verified,
    countsAsAttempt: false,
  );

  Future<Result<void, BullVaultFailure>> _mark(
    String walletId,
    VaultBackupDestination destination,
    VaultPublicationState state, {
    bool countsAsAttempt = true,
  }) => _write('mark ${state.name}', () async {
    await _database.transaction(() async {
      final current =
          await (_database.select(_database.vaultDescriptorPublications)..where(
                (row) =>
                    row.walletId.equals(walletId) &
                    row.destination.equals(destination.name),
              ))
              .getSingleOrNull();
      await _upsert(
        walletId: walletId,
        destination: destination,
        state: Value(state),
        attempts: Value((current?.attempts ?? 0) + (countsAsAttempt ? 1 : 0)),
      );
    });
  });

  Future<void> _upsert({
    required String walletId,
    required VaultBackupDestination destination,
    Value<bool> enabled = const Value.absent(),
    Value<Uint8List?> artifact = const Value.absent(),
    Value<String?> artifactSha256 = const Value.absent(),
    Value<VaultPublicationState> state = const Value.absent(),
    Value<int> attempts = const Value.absent(),
  }) async {
    await _database
        .into(_database.vaultDescriptorPublications)
        .insertOnConflictUpdate(
          VaultDescriptorPublicationsCompanion(
            walletId: Value(walletId),
            destination: Value(destination.name),
            enabled: enabled,
            artifact: artifact,
            artifactSha256: artifactSha256,
            state: state.present
                ? Value(state.value.name)
                : const Value.absent(),
            attempts: attempts,
            updatedAt: Value(_now().toUtc().millisecondsSinceEpoch),
          ),
        );
  }

  /// A row whose destination or state this build does not know is dropped
  /// rather than guessed at: it was written by a newer version.
  VaultDescriptorPublication? _map(VaultDescriptorPublicationRow row) {
    final destination = VaultBackupDestination.values
        .where((value) => value.name == row.destination)
        .firstOrNull;
    final state = VaultPublicationState.values
        .where((value) => value.name == row.state)
        .firstOrNull;
    if (destination == null || state == null) return null;
    return VaultDescriptorPublication(
      walletId: row.walletId,
      destination: destination,
      enabled: row.enabled,
      artifact: row.artifact,
      artifactSha256: row.artifactSha256,
      state: state,
      attempts: row.attempts,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAt,
        isUtc: true,
      ),
    );
  }

  Future<Result<T, BullVaultFailure>> _read<T>(
    String action,
    Future<T> Function() operation,
  ) async {
    try {
      return Ok(await operation());
    } on Exception catch (error, trace) {
      log.warning(
        'Descriptor publication $action failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(BullVaultBackupStatusFailure());
    }
  }

  Future<Result<void, BullVaultFailure>> _write(
    String action,
    Future<void> Function() operation,
  ) => _read(action, operation);
}
