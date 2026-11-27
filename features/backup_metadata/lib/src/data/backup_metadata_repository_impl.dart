import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:labels/backup.dart';
import 'package:backup_storage/backup_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/backup_metadata_failure.dart';
import '../domain/entities/backup_confirmation.dart';
import '../domain/entities/backup_content.dart';
import '../domain/entities/backup_status.dart';
import '../domain/entities/backup_summary.dart';
import '../domain/entities/discovered_backup.dart';
import '../domain/ports/backup_inventory_port.dart';
import '../domain/ports/backup_labels_port.dart';
import '../domain/ports/backup_secrets_port.dart';
import '../domain/repositories/backup_metadata_codec.dart';
import '../domain/repositories/backup_metadata_repository.dart';
import '../domain/content_sanitizer.dart';
import 'backup_content_localizer.dart';
import 'backup_metadata_store.dart';

const backupMetadataNamePrefix = 'bull-data-';
const backupMetadataMimeType = 'application/vnd.bull.backup+bip138';
const backupMetadataMaxBytes = 4 * 1024 * 1024;

final class BackupMetadataRepositoryImpl implements BackupMetadataRepository {
  final BackupMetadataStore _store;
  final BackupInventoryPort _inventory;
  final BackupLabelsPort _labels;
  final BackupSecretsPort _secrets;
  final BackupMetadataCodec _codec;
  final Map<BackupDestination, BackupStorage> _storages;

  BackupMetadataRepositoryImpl({
    required this._store,
    required this._inventory,
    required this._labels,
    required this._secrets,
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
  }) => _locked((state, live) async {
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
        account: selection.account,
      );
    }

    StorageSession? authorized;
    try {
      final session = await _authorize(destination, interactive: false);
      authorized = session;
      if (session.account.id != selection.account) {
        // The account behind the grant is not the one the user confirmed:
        // nothing is sent until they choose again (reconnect).
        throw const _OperationFailure(
          BackupMetadataAccountChangedFailure(),
          BackupActionReason.accountChanged,
        );
      }
      final listed = await _list(session);
      final groups = <BackupGroupStatus>[];
      var unattributedCount = 0;
      for (final group in inventory.groups) {
        if (!selection.groups.contains(group.id)) {
          groups.add(BackupGroupStatus(group: group, included: false));
          continue;
        }
        if (group.ambiguous) {
          // Its public key is carried by another wallet, possibly in another
          // view: it is never captured nor published.
          groups.add(
            BackupGroupStatus(
              group: group,
              included: true,
              pendingChanges: true,
              failure: const BackupMetadataIncompatibleFailure(),
              actionNeeded: BackupActionReason.ambiguous,
            ),
          );
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
        var excluded = 0;
        BackupMetadataFailure? failure;
        BackupActionReason? reason;
        String? digest;
        List<BackupGeneration>? durable;
        try {
          if (write) {
            await _reconcile(state, live, scope, session, listed);
          }
          final captured = _value(await _labels.capture(live, group));
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
          final content = sanitizeContent(
            BackupContent(
              labels: captured,
              wallets: group.wallets,
              derivations: _value(await _secrets.derivations(live, group)),
            ),
          );
          excluded = content.excluded;
          final prepared = _value(_codec.prepare(group, content));
          digest = prepared.digest;
          if (write && state.intent(scope) == null) {
            _admit(live);
            final latest = state.verified(scope).firstOrNull;
            if (latest == null ||
                latest.digest != digest ||
                !await _canSkipWrite(scope, session, listed, latest)) {
              await _create(state, live, scope, session, listed, prepared);
            }
            _admit(live);
            durable = await _prune(state, live, scope, session, listed);
          }
        } on _OperationFailure catch (error) {
          failure = error.failure;
          reason = error.reason;
        }
        if (durable == null) {
          try {
            durable = await _provenGenerations(
              scope,
              session,
              listed,
              state.verified(scope),
            );
          } on _OperationFailure catch (error) {
            failure ??= error.failure;
            reason ??= error.reason;
          }
        }
        final latest = durable?.firstOrNull;
        groups.add(
          BackupGroupStatus(
            group: group,
            included: true,
            lastDurableBackup: latest?.verifiedAt,
            previousVersionKept: (durable?.length ?? 0) > 1,
            pendingChanges:
                digest == null ||
                latest?.digest != digest ||
                state.intent(scope) != null,
            skippedCount: snapshot?.skippedCount ?? 0,
            excluded: excluded,
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
        account: selection.account,
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
    BackupSessionRef live,
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
      _admit(live);
      state.discardIntent(scope);
      return;
    }
    final read = await session.read(object, maxBytes: backupMetadataMaxBytes);
    if (read case Err(failure: BackupStorageTooLargeFailure())) {
      // Our own writes never exceed the cap, so the listed bytes are not the
      // ones this intent wrote.
      _admit(live);
      state.discardIntent(scope);
      return;
    }
    final bytes = _storageValue(read);
    if (sha256.convert(bytes).toString() != intent.envelopeDigest) {
      // The bytes were read back in full and differ from what this intent
      // wrote: the mismatch is confirmed, not a transient read failure, which
      // keeps the intent by throwing above. Retire the intent without
      // acknowledging or pruning the damaged object, so this run uploads a
      // fresh generation under a new name instead of reconciling it forever.
      _admit(live);
      state.discardIntent(scope);
      return;
    }
    await _confirm(state, live, scope, session, listed, object, intent);
  }

  Future<void> _create(
    BackupMetadataState state,
    BackupSessionRef live,
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
    // Encryption took time: the session may have ended, or been reopened as a
    // new one, since. The check, the journal write and the start of the
    // upload follow one another without yielding.
    _admit(live);
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
    // Not admitted again, on purpose: the upload was admitted above and this
    // only records the object it created. Skipping it would leave an object on
    // the destination that the journal never learns it owns.
    state.recordCreated(scope, object.id);
    await _verifyCreated(state, live, scope, session, listed, object, intent);
  }

  /// Confirms an object this run has just created. A mismatch keeps the
  /// intent: the write's response may still be in flight, and a later run
  /// reconciles it.
  Future<void> _verifyCreated(
    BackupMetadataState state,
    BackupSessionRef live,
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
    // The intent's original ciphertext digest also proves a folder write
    // whose response or durable receipt was lost.
    if (sha256.convert(bytes).toString() != intent.envelopeDigest) {
      throw const _OperationFailure.unexpected();
    }
    await _confirm(state, live, scope, session, listed, object, intent);
  }

  Future<void> _confirm(
    BackupMetadataState state,
    BackupSessionRef live,
    BackupScope scope,
    StorageSession session,
    Map<String, StoredObject> listed,
    StoredObject object,
    BackupIntent intent,
  ) async {
    final refreshed = await _list(session);
    listed
      ..clear()
      ..addAll(refreshed);
    if (!await _hasDurabilityProof(
      scope,
      session,
      listed[object.id],
      intent.envelopeDigest,
    )) {
      return;
    }

    // An acknowledgement is a journal write: it needs the live session. The
    // intent stays, and a later run reconciles it.
    _admit(live);
    state.acknowledge(
      scope,
      intent,
      objectId: object.id,
      verifiedAt: DateTime.now().toUtc(),
    );
  }

  Future<bool> _canSkipWrite(
    BackupScope scope,
    StorageSession session,
    Map<String, StoredObject> listed,
    BackupGeneration latest,
  ) async {
    final object = listed[latest.objectId];
    if (scope.destination != BackupDestination.folder) return object != null;
    return _hasDurabilityProof(scope, session, object, latest.envelopeDigest);
  }

  Future<bool> _hasDurabilityProof(
    BackupScope scope,
    StorageSession session,
    StoredObject? object,
    String envelopeDigest,
  ) async {
    if (object == null) return false;
    if (object.durability == Durability.durable) return true;
    if (scope.destination != BackupDestination.folder) return false;

    final result = await session.read(object, maxBytes: backupMetadataMaxBytes);
    if (result case Err(
      failure: BackupStorageNotFoundFailure() || BackupStorageTooLargeFailure(),
    )) {
      return false;
    }
    final bytes = _storageValue(result);
    return bytes.length <= backupMetadataMaxBytes &&
        sha256.convert(bytes).toString() == envelopeDigest;
  }

  Future<List<BackupGeneration>> _provenGenerations(
    BackupScope scope,
    StorageSession session,
    Map<String, StoredObject> listed,
    List<BackupGeneration> generations,
  ) async => [
    for (final backup in generations)
      if (await _hasDurabilityProof(
        scope,
        session,
        listed[backup.objectId],
        backup.envelopeDigest,
      ))
        backup,
  ];

  Future<List<BackupGeneration>> _prune(
    BackupMetadataState state,
    BackupSessionRef live,
    BackupScope scope,
    StorageSession session,
    Map<String, StoredObject> listed,
  ) async {
    final generations = state.verified(scope);
    if (generations.length >= 3) {
      // Revalidate every candidate against the latest listing before deletion.
      final refreshed = await _list(session);
      listed
        ..clear()
        ..addAll(refreshed);
    }
    final durable = await _provenGenerations(
      scope,
      session,
      listed,
      generations,
    );
    for (final old in durable.skip(2)) {
      final object = listed[old.objectId];
      if (object == null) continue;
      await _delete(
        state,
        live,
        scope.destination,
        session,
        scope.lineage,
        object,
      );
      listed.remove(old.objectId);
    }
    return durable.take(2).toList();
  }

  @override
  Future<Result<List<DiscoveredBackup>, BackupMetadataFailure>> discover(
    BackupDestination destination,
  ) => _locked((_, live) async {
    final inventory = _value(await _inventory.read());
    final session = await _authorizeForDiscovery(destination);
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
      BackupMetadataFailure? decodeFailure;
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
        for (final group in inventory.groups.where(
          (group) => !group.ambiguous,
        )) {
          final decoded = await _codec.decode(group, bytes);
          switch (decoded) {
            case Ok(value: final backup?):
              discovered.add(
                DiscoveredBackup(
                  group: group,
                  destination: destination,
                  storedAt: object.createdAt ?? object.modifiedAt,
                  content: localizeContent(group, sanitizeContent(backup)),
                  scope: live,
                ),
              );
            case Ok():
              // This copy did not authenticate for this group.
              break;
            case Err(:final failure):
              decodeFailure ??= failure;
          }
        }
      }
      if (discovered.isEmpty && decodeFailure != null) {
        // Nothing usable was found and at least one copy failed to decode:
        // reporting an empty destination would hide a damaged backup.
        throw _OperationFailure(decodeFailure, BackupActionReason.unexpected);
      }
      _admit(live);
      return List<DiscoveredBackup>.unmodifiable(discovered);
    } finally {
      await session.close();
    }
  });

  @override
  Future<Result<BackupSummary, BackupMetadataFailure>> summary() =>
      _locked((state, live) async {
        final selection = state.selection;
        return BackupSummary(
          enabled: selection.destination != null && selection.groups.isNotEmpty,
          lastDurableBackup: state.lastVerified(selection.lineage),
        );
      });

  @override
  Future<Result<BackupConfirmation, BackupMetadataFailure>> stage(
    BackupDestination destination,
    Set<String> groups,
  ) => _locked((state, live) async {
    final session = await _authorize(destination, interactive: true);
    try {
      _admit(live);
      final token = state.stage(destination, session.account.id, groups);
      return BackupConfirmation(
        destination: destination,
        account: session.account.id,
        generation: state.selection.generation,
        session: live,
        token: token,
        groups: Set.unmodifiable(groups),
      );
    } finally {
      session.dispose();
    }
  });

  @override
  Future<Result<void, BackupMetadataFailure>> discardStaged() =>
      _locked((state, live) async {
        _admit(live);
        state.clearStaged();
      });

  @override
  Future<Result<void, BackupMetadataFailure>> include(
    Set<String> groups,
    BackupConfirmation confirmation,
  ) => _locked((state, live) async {
    final selection = state.selection;
    // One conditional write of exactly what was shown: the destination and
    // account that were granted, the generation they replace, the session.
    if (!confirmation.session.isCurrent ||
        confirmation.session.view != live.view ||
        selection.pendingDestination != confirmation.destination ||
        selection.pendingAccount != confirmation.account ||
        selection.pendingToken != confirmation.token ||
        selection.pendingGroups.length != groups.length ||
        !selection.pendingGroups.containsAll(groups) ||
        groups.length != confirmation.groups.length ||
        !confirmation.groups.containsAll(groups) ||
        selection.generation != confirmation.generation) {
      throw const _OperationFailure(
        BackupMetadataScopeChangedFailure(),
        BackupActionReason.unexpected,
      );
    }
    _admit(live);
    state.configure(
      destination: confirmation.destination,
      account: confirmation.account,
      groups: groups,
    );
  });

  @override
  Future<Result<void, BackupMetadataFailure>> configure({
    required BackupDestination? destination,
    required Set<String> groups,
    required bool deleteOwnedFiles,
  }) => _locked((state, live) async {
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
              live,
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
      _admit(live);
      state.configure(destination: null, account: null, groups: groups);
      return;
    }
    final session = await _authorize(destination, interactive: true);
    try {
      // The grant may have taken time (a chooser): the session may have ended.
      _admit(live);
      if (groups.isEmpty) {
        // Nothing is chosen: granted, not on.
        state.stage(destination, session.account.id, const {});
        return;
      }
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
    BackupSessionRef live,
    BackupDestination destination,
    StorageSession session,
    String lineage,
    StoredObject object,
  ) async {
    _admit(live);
    final result = await session.delete(object);
    if (result case Err(:final failure)
        when failure is! BackupStorageNotFoundFailure) {
      _storageValue(result);
    }
    // Not admitted again, on purpose: the deletion was admitted just above and
    // this forgets the object it removed. Keeping the entry would make a later
    // run delete a name that is already gone.
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

  /// Reads a destination without touching the configured grant: browsing for
  /// a restore file never changes where scheduled backups are written.
  Future<StorageReadSession> _authorizeForDiscovery(
    BackupDestination destination,
  ) async {
    final storage = _storages[destination];
    if (storage == null) throw const _OperationFailure.unexpected();
    return _storageValue(await storage.authorizeForDiscovery());
  }

  Future<Map<String, StoredObject>> _list(StorageReadSession session) async {
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

  /// Revokes an operation whose session ended, before an effect starts. It is
  /// synchronous: the check and the effect's first step cannot be separated by
  /// a lock.
  void _admit(BackupSessionRef live) {
    if (!live.isCurrent) {
      throw const _OperationFailure(
        BackupMetadataScopeChangedFailure(),
        BackupActionReason.unexpected,
      );
    }
  }

  Future<Result<T, BackupMetadataFailure>> _locked<T>(
    Future<T> Function(BackupMetadataState, BackupSessionRef live) action,
  ) async {
    final opened = await _secrets.session();
    if (opened is! Ok<BackupSessionRef, BackupMetadataFailure>) {
      return const Err(BackupMetadataNotReadyFailure());
    }
    final live = opened.value;
    try {
      return Ok(
        await _store.locked((state) => action(state, live), view: live.view),
      );
    } on _OperationFailure catch (error) {
      return Err(error.failure);
    } on BackupMetadataStoreNotReady {
      return const Err(BackupMetadataNotReadyFailure());
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
