import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:labels/backup.dart';
import 'package:backup_storage/backup_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/backup_metadata_failure.dart';
import '../domain/entities/backup_status.dart';
import '../domain/entities/discovered_backup.dart';
import '../domain/ports/backup_inventory_port.dart';
import '../domain/ports/backup_labels_port.dart';
import '../domain/repositories/backup_metadata_codec.dart';
import '../domain/repositories/backup_metadata_repository.dart';
import 'backup_metadata_store.dart';

const backupMetadataNamePrefix = 'bull-data-';
const backupMetadataMimeType = 'application/vnd.bull.backup+bip138';
const backupMetadataMaxBytes = 4 * 1024 * 1024;

final class BackupMetadataRepositoryImpl implements BackupMetadataRepository {
  final BackupMetadataStore _store;
  final BackupInventoryPort _inventory;
  final BackupLabelsPort _labels;
  final BackupMetadataCodec _codec;
  final Map<BackupDestination, BackupStorage> _storages;

  BackupMetadataRepositoryImpl({
    required this._store,
    required this._inventory,
    required this._labels,
    required this._codec,
    required Iterable<BackupStorage> storages,
  }) : _storages = {
         for (final storage in storages) storage.destination: storage,
       };

  @override
  Future<Result<BackupRunStatus, BackupMetadataFailure>> run() =>
      _inspect(write: true);

  @override
  Future<Result<BackupRunStatus, BackupMetadataFailure>> status() =>
      _inspect(write: false);

  Future<Result<BackupRunStatus, BackupMetadataFailure>> _inspect({
    required bool write,
  }) => _locked((state) async {
    final inventory = _value(await _inventory.read());
    var selection = state.selection;
    final destination = selection.destination;
    final selected = inventory.groups.where(
      (group) => selection.groups.contains(group.id),
    );
    if (destination == null || selected.isEmpty) {
      return BackupRunStatus(
        destination: destination,
        groups: [
          for (final group in inventory.groups)
            BackupGroupStatus(group: group, included: false),
        ],
        unsupported: inventory.unsupported,
        unattributedCount: 0,
      );
    }

    StorageSession? authorized;
    try {
      final session = await _authorize(destination, interactive: false);
      authorized = session;
      if (session.account.id != selection.account) {
        state.configure(
          destination: destination,
          account: session.account.id,
          groups: selection.groups,
        );
        selection = state.selection;
      }
      final listed = await _list(session);
      final groups = <BackupGroupStatus>[];
      var unattributedCount = 0;
      for (final group in inventory.groups) {
        if (!selection.groups.contains(group.id)) {
          groups.add(BackupGroupStatus(group: group, included: false));
          continue;
        }
        final scope = (
          destination: destination,
          account: session.account.id,
          group: group.id,
          lineage: selection.lineage,
          generation: selection.generation,
        );
        LabelsSnapshot? snapshot;
        BackupMetadataFailure? failure;
        BackupActionReason? reason;
        String? digest;
        try {
          if (write) {
            await _reconcile(state, scope, session, listed);
          }
          final captured = _value(await _labels.capture(group));
          snapshot = captured;
          unattributedCount = max(
            unattributedCount,
            captured.unattributedCount,
          );
          if (captured.skippedCount > 0) {
            throw const _OperationFailure.unexpected(
              BackupActionReason.incompleteCapture,
            );
          }
          final prepared = _value(_codec.prepare(group, captured));
          digest = prepared.digest;
          if (write && state.intent(scope) == null) {
            final latest = state.verified(scope).firstOrNull;
            if (latest == null ||
                latest.digest != digest ||
                !listed.containsKey(latest.objectId)) {
              await _create(state, scope, session, listed, prepared);
            }
            await _prune(state, scope, session, listed);
          }
        } on _OperationFailure catch (error) {
          failure = error.failure;
          reason = error.reason;
        }
        final durable = state
            .verified(scope)
            .where((backup) => _durable(scope, listed[backup.objectId]));
        final latest = durable.firstOrNull;
        groups.add(
          BackupGroupStatus(
            group: group,
            included: true,
            lastDurableBackup: latest?.verifiedAt,
            previousVersionKept: durable.skip(1).isNotEmpty,
            pendingChanges:
                digest == null ||
                latest?.digest != digest ||
                state.intent(scope) != null,
            skippedCount: snapshot?.skippedCount ?? 0,
            failure: failure,
            actionNeeded: reason,
          ),
        );
      }
      return BackupRunStatus(
        destination: destination,
        groups: List.unmodifiable(groups),
        unsupported: inventory.unsupported,
        unattributedCount: unattributedCount,
      );
    } on _OperationFailure catch (error) {
      return BackupRunStatus(
        destination: destination,
        groups: [
          for (final group in inventory.groups)
            if (selection.groups.contains(group.id))
              BackupGroupStatus(
                group: group,
                included: true,
                pendingChanges: true,
                failure: error.failure,
                actionNeeded: error.reason,
              )
            else
              BackupGroupStatus(group: group, included: false),
        ],
        unsupported: inventory.unsupported,
        unattributedCount: 0,
      );
    } finally {
      authorized?.dispose();
    }
  });

  Future<void> _reconcile(
    BackupMetadataState state,
    BackupScope scope,
    StorageSession session,
    Map<String, StoredObject> listed,
  ) async {
    final intent = state.intent(scope);
    if (intent == null) return;
    final objectId = intent.objectId;
    final candidates = listed.values.where(
      (object) =>
          object.name == intent.name &&
          (objectId == null || object.id == objectId),
    );
    if (candidates.length > 1) throw const _OperationFailure.unexpected();
    final object = candidates.firstOrNull;
    if (object == null) {
      // A create can finish after its response was lost. Retire this name
      // before retrying, so a late object never aliases a new attempt.
      state.discardIntent(scope);
      return;
    }
    await _verify(state, scope, session, listed, object, intent);
  }

  Future<void> _create(
    BackupMetadataState state,
    BackupScope scope,
    StorageSession session,
    Map<String, StoredObject> listed,
    PreparedBackup prepared,
  ) async {
    final bytes = _value(await prepared.encrypt());
    if (bytes.length > backupMetadataMaxBytes) {
      throw const _OperationFailure(
        BackupMetadataTooLargeFailure(),
        BackupActionReason.tooLarge,
      );
    }
    final name = '$backupMetadataNamePrefix${randomHex(8)}.bip138';
    final BackupIntent intent = (
      name: name,
      digest: prepared.digest,
      envelopeDigest: sha256.convert(bytes).toString(),
      objectId: null,
    );
    state.begin(scope, intent);
    final object = _storageValue(
      await session.create(
        name: name,
        mimeType: backupMetadataMimeType,
        bytes: bytes,
      ),
    );
    state.recordCreated(scope, object.id);
    await _verify(state, scope, session, listed, object, intent);
  }

  Future<void> _verify(
    BackupMetadataState state,
    BackupScope scope,
    StorageSession session,
    Map<String, StoredObject> listed,
    StoredObject object,
    BackupIntent intent,
  ) async {
    final Uint8List bytes = _storageValue(
      await session.read(object, maxBytes: backupMetadataMaxBytes),
    );
    if (bytes.length > backupMetadataMaxBytes) {
      throw const _OperationFailure(
        BackupMetadataTooLargeFailure(),
        BackupActionReason.tooLarge,
      );
    }
    // The journal binds the canonical digest to the exact encrypted bytes.
    // Read-back verification therefore works even if descriptors have changed.
    if (sha256.convert(bytes).toString() != intent.envelopeDigest) {
      throw const _OperationFailure.unexpected();
    }
    final refreshed = await _list(session);
    listed
      ..clear()
      ..addAll(refreshed);
    if (!_durable(scope, listed[object.id])) return;

    state.acknowledge(scope, (
      objectId: object.id,
      digest: intent.digest,
      verifiedAt: DateTime.now().toUtc(),
    ));
  }

  bool _durable(BackupScope scope, StoredObject? object) =>
      object != null &&
      (object.durability == Durability.durable ||
          scope.destination == BackupDestination.folder);

  Future<void> _prune(
    BackupMetadataState state,
    BackupScope scope,
    StorageSession session,
    Map<String, StoredObject> listed,
  ) async {
    final generations = state.verified(scope);
    if (generations.length < 3) return;

    // Re-list before any deletion, especially for providers with pending uploads.
    final refreshed = await _list(session);
    listed
      ..clear()
      ..addAll(refreshed);
    final durable = generations.where(
      (backup) => _durable(scope, listed[backup.objectId]),
    );
    for (final old in durable.skip(2)) {
      final object = listed[old.objectId];
      if (object == null) continue;
      await _delete(state, scope.destination, session, scope.lineage, object);
      listed.remove(old.objectId);
    }
  }

  @override
  Future<Result<List<DiscoveredBackup>, BackupMetadataFailure>> discover(
    BackupDestination destination,
  ) => _locked((_) async {
    final inventory = _value(await _inventory.read());
    final session = await _authorize(destination, interactive: true);
    try {
      final objects = (await _list(session)).values.toList()
        ..sort((a, b) {
          final first = a.createdAt ?? a.modifiedAt;
          final second = b.createdAt ?? b.modifiedAt;
          return (second?.millisecondsSinceEpoch ?? 0).compareTo(
            first?.millisecondsSinceEpoch ?? 0,
          );
        });
      final discovered = <DiscoveredBackup>[];
      for (final object in objects) {
        if ((object.size ?? 0) > backupMetadataMaxBytes) continue;
        final result = await session.read(
          object,
          maxBytes: backupMetadataMaxBytes,
        );
        if (result case Err(
          failure: BackupStorageTooLargeFailure() ||
              BackupStorageNotFoundFailure(),
        )) {
          continue;
        }
        final bytes = _storageValue(result);
        if (bytes.length > backupMetadataMaxBytes) continue;
        for (final group in inventory.groups) {
          final decoded = await _codec.decode(group, bytes);
          if (decoded case Ok(value: final backup?)) {
            discovered.add(
              DiscoveredBackup(
                group: group,
                destination: destination,
                storedAt: object.createdAt ?? object.modifiedAt,
                snapshot: backup,
              ),
            );
          }
        }
      }
      return List<DiscoveredBackup>.unmodifiable(discovered);
    } finally {
      session.dispose();
    }
  });

  @override
  Future<Result<void, BackupMetadataFailure>> configure({
    required BackupDestination? destination,
    required Set<String> groups,
    required bool deleteOwnedFiles,
  }) => _locked((state) async {
    final previous = state.selection;
    final previousDestination = previous.destination;
    if (destination == null &&
        deleteOwnedFiles &&
        previousDestination != null) {
      final session = await _authorize(previousDestination, interactive: false);
      try {
        if (session.account.id != previous.account) {
          throw const _OperationFailure.unexpected();
        }
        final owned = state.owned(
          previousDestination,
          session.account.id,
          previous.lineage,
        );
        final listed = await _list(session);
        for (final id in owned) {
          final object = listed[id];
          if (object != null) {
            await _delete(
              state,
              previousDestination,
              session,
              previous.lineage,
              object,
            );
          }
        }
      } finally {
        session.dispose();
      }
    }
    if (destination == null) {
      state.configure(destination: null, account: null, groups: groups);
      return;
    }
    final session = await _authorize(destination, interactive: true);
    try {
      state.configure(
        destination: destination,
        account: session.account.id,
        groups: groups,
      );
    } finally {
      session.dispose();
    }
  });

  Future<void> _delete(
    BackupMetadataState state,
    BackupDestination destination,
    StorageSession session,
    String lineage,
    StoredObject object,
  ) async {
    final result = await session.delete(object);
    if (result case Err(:final failure)
        when failure is! BackupStorageNotFoundFailure) {
      _storageValue(result);
    }
    state.forget(destination, session.account.id, lineage, object.id);
  }

  Future<StorageSession> _authorize(
    BackupDestination destination, {
    required bool interactive,
  }) async {
    final storage = _storages[destination];
    if (storage == null) throw const _OperationFailure.unexpected();
    return _storageValue(await storage.authorize(interactive: interactive));
  }

  Future<Map<String, StoredObject>> _list(StorageSession session) async {
    final objects = _storageValue(
      await session.list(
        mimeType: backupMetadataMimeType,
        namePrefix: backupMetadataNamePrefix,
      ),
    );
    return {
      for (final object in objects)
        if (object.name.startsWith(backupMetadataNamePrefix) &&
            object.name.endsWith('.bip138'))
          object.id: object,
    };
  }

  Future<Result<T, BackupMetadataFailure>> _locked<T>(
    Future<T> Function(BackupMetadataState) action,
  ) async {
    try {
      return Ok(await _store.locked(action));
    } on _OperationFailure catch (error) {
      return Err(error.failure);
    } on SqliteException {
      return const Err(BackupMetadataUnexpectedFailure());
    } on FileSystemException {
      return const Err(BackupMetadataUnexpectedFailure());
    } on FormatException {
      return const Err(BackupMetadataUnexpectedFailure());
    }
  }

  T _value<T>(Result<T, BackupMetadataFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw _OperationFailure(
      failure,
      failure is BackupMetadataTooLargeFailure
          ? BackupActionReason.tooLarge
          : BackupActionReason.unexpected,
    ),
  };

  T _storageValue<T>(Result<T, BackupStorageFailure> result) =>
      switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw switch (failure) {
          BackupStorageTooLargeFailure() => const _OperationFailure(
            BackupMetadataTooLargeFailure(),
            BackupActionReason.tooLarge,
          ),
          BackupStorageAuthorizationRequiredFailure() =>
            const _OperationFailure.unexpected(
              BackupActionReason.authorizationRequired,
            ),
          BackupStorageCancelledFailure() => const _OperationFailure.unexpected(
            BackupActionReason.cancelled,
          ),
          BackupStoragePermissionRevokedFailure() =>
            const _OperationFailure.unexpected(
              BackupActionReason.permissionRevoked,
            ),
          BackupStorageQuotaExceededFailure() =>
            const _OperationFailure.unexpected(
              BackupActionReason.quotaExceeded,
            ),
          BackupStorageUnavailableFailure() =>
            const _OperationFailure.unexpected(BackupActionReason.unavailable),
          BackupStorageNotFoundFailure() || BackupStorageUnexpectedFailure() =>
            const _OperationFailure.unexpected(),
        },
      };
}

final class _OperationFailure implements Exception {
  final BackupMetadataFailure failure;
  final BackupActionReason reason;

  const _OperationFailure(this.failure, this.reason);

  const _OperationFailure.unexpected([
    this.reason = BackupActionReason.unexpected,
  ]) : failure = const BackupMetadataUnexpectedFailure();
}
