import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart'
    show
        GeneratedDatabase,
        BooleanExpressionOperators,
        OrderingTerm,
        TableUpdateQuery;
import 'package:labels/labels_table.dart';
import 'package:labels/labels_table.drift.dart';
import 'package:primitives/primitives.dart';

import '../domain/bip329_wallet_origin.dart';
import '../domain/label_backup_scope.dart';
import '../domain/label_entity.dart';
import '../domain/label_failure.dart';
import '../domain/labels_merge.dart';
import '../domain/labels_snapshot.dart';
import '../domain/new_label.dart';
import '../domain/primitive/label_system.dart';
import '../domain/primitive/label_type.dart';
import '../domain/wallet_freeze_port.dart';
import 'drift_labels_repository.dart';
import 'frozen_utxos_freeze_store.dart';
import 'label_row_mapper.dart';

typedef _LabelKey = (BackupLabelChain, BackupLabelType, String);
typedef _SqlKey = (String, String);

final class LabelBackupRepository {
  final GeneratedDatabase _database;
  final WalletFreezePort _walletFreeze;
  final DriftLabelsRepository _labels;
  final FrozenUtxosFreezeStore _freezes;

  LabelBackupRepository({
    required GeneratedDatabase database,
    required this._walletFreeze,
  }) : _database = database,
       _labels = DriftLabelsRepository(database: database),
       _freezes = FrozenUtxosFreezeStore(database: database);

  Stream<void> get changes => _database
      .tableUpdates(
        TableUpdateQuery.onAllTables([
          _labels.labelsTable,
          _freezes.frozenUtxos,
        ]),
      )
      .map((_) {});

  Future<Result<LabelsSnapshot, LabelFailure>> capture(
    LabelBackupScope scope,
  ) async {
    return _run(
      () => _database.transaction(() async {
        final rows = await _readRows();
        final freezes = _database.select(_freezes.frozenUtxos)
          ..orderBy([
            (row) => OrderingTerm.asc(row.walletId),
            (row) => OrderingTerm.asc(row.txId),
            (row) => OrderingTerm.asc(row.vout),
          ]);
        final frozen = <(String, String)>{
          for (final row in await freezes.get())
            if (scope.wallets.containsKey(row.walletId))
              (row.walletId, '${row.txId}:${row.vout}'),
        };
        final records = <BackupLabelRecord>[];
        var unattributed = 0;
        var skipped = 0;
        for (final row in rows) {
          final label = row.labelEntity();
          if (label == null || label.reference.isEmpty) {
            skipped++;
            continue;
          }
          final walletId = _resolveOrigin(label.origin, scope.allWallets);
          final chain = scope.wallets[walletId];
          if (walletId == null) unattributed++;
          if (chain == null || walletId == null) continue;
          final type = _backupType(label.type);
          final frozenOutput =
              type == BackupLabelType.output &&
              frozen.contains((walletId, label.reference));
          records.add(
            BackupLabelRecord(
              chain: chain,
              type: type,
              ref: label.reference,
              label: label.label,
              origin: bip329OriginFromWalletId(walletId),
              spendable: frozenOutput ? false : null,
              walletId: walletId,
            ),
          );
        }
        final labeledOutputs = {
          for (final record in records)
            if (record.type == BackupLabelType.output)
              (record.walletId, record.ref),
        };
        for (final (walletId, ref) in frozen) {
          final chain = scope.wallets[walletId];
          if (chain == null || labeledOutputs.contains((walletId, ref))) {
            continue;
          }
          records.add(
            BackupLabelRecord(
              chain: chain,
              type: BackupLabelType.output,
              ref: ref,
              origin: bip329OriginFromWalletId(walletId),
              spendable: false,
              walletId: walletId,
            ),
          );
        }
        return LabelsSnapshot(
          records: records,
          unattributedCount: unattributed,
          skippedCount: skipped,
        );
      }),
    );
  }

  Future<Result<MergePlan, LabelFailure>> preview(
    LabelBackupScope scope,
    LabelsSnapshot incoming,
  ) async {
    return _run(() async {
      final rows = await _readRows();
      final local = _localLabels(rows, scope);
      final additions = <BackupLabelRecord>[];
      final conflicts = <_LabelKey, LabelConflict>{};
      final freezes = <FreezeRequest>{};
      final seen =
          <(BackupLabelChain, BackupLabelType, String, String, String?)>{};
      var unchanged = 0;
      for (final record in incoming.records) {
        final walletId = _incomingWallet(record, scope);
        final freezeWallet = record.walletId;
        if (record.spendable == false &&
            freezeWallet != null &&
            freezeWallet.isNotEmpty &&
            (scope.wallets[freezeWallet] == null ||
                scope.wallets[freezeWallet] == record.chain)) {
          freezes.add(
            FreezeRequest(walletId: freezeWallet, outpoint: record.ref),
          );
        }
        final text = record.label;
        if (text == null) continue;
        final label = LabelEntity.sanitizeLabel(text);
        if (label.isEmpty && record.spendable == false) continue;
        final key = (record.chain, record.type, record.ref);
        if (!seen.add((
          record.chain,
          record.type,
          record.ref,
          label,
          walletId,
        ))) {
          continue;
        }
        final matches = local[key]?.where((item) => item.origin == walletId);
        if (walletId == null || LabelSystem.isSystemLabel(label)) {
          additions.add(record);
        } else if (matches?.any((item) => item.label == label) ?? false) {
          unchanged++;
        } else if (matches?.firstOrNull case final previous?) {
          // A conflict can reconstruct the wallet only from the local record.
          // If legacy rows normalize to the same label, retain explicit
          // attribution in the addition instead of guessing at apply time.
          if (conflicts.containsKey(key) ||
              local[key]
                      ?.where((item) => item.label == previous.label)
                      .length !=
                  1) {
            additions.add(record);
          } else {
            conflicts[key] = LabelConflict(
              chain: record.chain,
              type: record.type,
              ref: record.ref,
              localLabel: previous.label,
              incomingLabel: label,
            );
          }
        } else {
          additions.add(record);
        }
      }
      return MergePlan(
        groupId: scope.groupId,
        baseDigest: _digest(rows, scope),
        additions: additions,
        unchanged: unchanged,
        conflicts: conflicts.values.toList(),
        freezes: freezes.toList(),
      );
    });
  }

  Future<Result<ApplyReport, LabelFailure>> apply(
    LabelBackupScope scope,
    MergePlan plan,
    MergeChoices choices,
  ) async {
    return _run(() async {
      if (scope.groupId != plan.groupId) throw const _StalePlan();
      final writes = await _database.transaction(
        () => _applyLabels(scope, plan, choices),
      );
      final freezes = <FreezeRequest, FreezeOutcome>{};
      for (final request in plan.freezes) {
        freezes[request] = await _applyFreeze(scope, request);
      }
      return ApplyReport(
        labelsApplied: writes.applied,
        labelsUnchanged: writes.unchanged,
        labelsRejected: writes.rejected,
        freezes: freezes,
      );
    });
  }

  Future<_LabelWrites> _applyLabels(
    LabelBackupScope scope,
    MergePlan plan,
    MergeChoices choices,
  ) async {
    final rows = await _readRows();
    final local = _localLabels(rows, scope);
    final kept = plan.conflicts.where(
      (conflict) =>
          choices.resolutions[conflict] != ConflictResolution.useBackup,
    );
    final keptKeys = {
      for (final conflict in kept)
        (conflict.chain, conflict.type, conflict.ref),
    };
    final blocked = plan.additions
        .where(
          (record) =>
              keptKeys.contains((record.chain, record.type, record.ref)) &&
              !LabelSystem.isSystemLabel(
                LabelEntity.sanitizeLabel(record.label ?? ''),
              ),
        )
        .toSet();
    final selected = <BackupLabelRecord>[
      ...plan.additions.where((record) => !blocked.contains(record)),
      for (final conflict in plan.conflicts)
        if (choices.resolutions[conflict] == ConflictResolution.useBackup)
          BackupLabelRecord(
            chain: conflict.chain,
            type: conflict.type,
            ref: conflict.ref,
            label: conflict.incomingLabel,
            walletId: _conflictWallet(local, conflict),
          ),
    ];
    final rejected = <LabelRejection, int>{};
    void reject(LabelRejection reason) =>
        rejected.update(reason, (count) => count + 1, ifAbsent: () => 1);

    final pending = <_SqlKey, NewLabel>{};
    for (final record in selected) {
      final text = record.label;
      final walletId = _incomingWallet(record, scope);
      if (text == null) {
        reject(LabelRejection.invalid);
        continue;
      }
      final label = LabelEntity.sanitizeLabel(text);
      if (LabelSystem.isSystemLabel(label)) {
        reject(LabelRejection.reservedLabel);
        continue;
      }
      if (walletId == null) {
        reject(LabelRejection.notOwned);
        continue;
      }
      final type = _labelType(record.type);
      try {
        LabelEntity(id: 0, type: type, label: label, reference: record.ref);
      } on LabelValidationException {
        reject(LabelRejection.invalid);
        continue;
      }
      final key = (label, record.ref);
      final proposal = NewLabel(
        type: type,
        reference: record.ref,
        label: label,
        origin: walletId,
      );
      final previous = pending[key];
      if (previous == null) {
        pending[key] = proposal;
      } else if (previous.type != type || previous.origin != walletId) {
        reject(LabelRejection.notOwned);
      }
    }

    final existing = {for (final row in rows) row.key: row};
    final alreadyWritten = {
      for (final entry in pending.entries)
        if (existing[entry.key]?.exactlyMatches(entry.value) ?? false)
          entry.key,
    };
    final fresh = _digest(rows, scope) == plan.baseDigest;
    // A retry may see rows this same plan already inserted. Removing exactly
    // those rows must recover the original digest; unrelated edits still fail.
    final replay =
        alreadyWritten.isNotEmpty &&
        _digest(
              rows.where((row) => !alreadyWritten.contains(row.key)),
              scope,
            ) ==
            plan.baseDigest;
    if (!fresh && !replay) throw const _StalePlan();

    var applied = 0;
    var unchanged = plan.unchanged + kept.length + blocked.length;
    for (final entry in pending.entries) {
      final row = existing[entry.key];
      if (row == null) {
        await _labels.store(entry.value);
        applied++;
      } else if (row.sameAttribution(entry.value, scope)) {
        unchanged++;
      } else {
        // Drift's upsert would replace the existing origin on a SQL collision.
        reject(LabelRejection.notOwned);
      }
    }
    return _LabelWrites(applied, unchanged, rejected);
  }

  Future<FreezeOutcome> _applyFreeze(
    LabelBackupScope scope,
    FreezeRequest request,
  ) async {
    if (!scope.wallets.containsKey(request.walletId)) {
      return FreezeOutcome.notOwned;
    }
    final parts = request.outpoint.split(':');
    final vout = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (vout == null ||
        vout < 0 ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(parts.first)) {
      return FreezeOutcome.notOwned;
    }
    final outpoint = (txId: parts.first, vout: vout);
    try {
      final frozen =
          await (_database.select(_freezes.frozenUtxos)..where(
                (row) =>
                    row.walletId.equals(request.walletId) &
                    row.txId.equals(outpoint.txId) &
                    row.vout.equals(outpoint.vout),
              ))
              .getSingleOrNull();
      if (frozen != null) return FreezeOutcome.applied;

      final verified = await _walletFreeze.ownedImportedFreezes(
        request.walletId,
        [
          (
            walletId: request.walletId,
            txId: outpoint.txId,
            vout: outpoint.vout,
          ),
        ],
      );
      if (verified.isEmpty) return FreezeOutcome.pendingDiscovery;
      // Sync uses an insert-if-absent for durable freezes.
      await _walletFreeze.freeze(verified);
      return FreezeOutcome.applied;
    } on Exception {
      return FreezeOutcome.failed;
    }
  }

  Future<Result<T, LabelFailure>> _run<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return Ok(await operation());
    } on _StalePlan {
      return const Err(LabelBackupStalePlanFailure());
    } on Exception {
      return const Err(LabelUnexpectedFailure());
    }
  }

  Future<List<_StoredLabel>> _readRows() async {
    final rows = await _database
        .customSelect(
          '''
      SELECT id, label, reference, type, origin FROM labels
      ORDER BY label, reference
    ''',
          readsFrom: {_labels.labelsTable},
        )
        .get();
    return [
      for (final row in rows)
        _StoredLabel(
          row.read<int>('id'),
          row.read<String>('label'),
          row.read<String>('reference'),
          row.read<String>('type'),
          row.readNullable<String>('origin'),
        ),
    ];
  }
}

final class _StoredLabel {
  final int id;
  final String label;
  final String reference;
  final String type;
  final String? origin;

  const _StoredLabel(
    this.id,
    this.label,
    this.reference,
    this.type,
    this.origin,
  );

  _SqlKey get key => (label, reference);

  LabelEntity? labelEntity() {
    final category = LabelTypeColumn.values
        .where((item) => item.name == type)
        .firstOrNull;
    if (category == null) return null;
    try {
      return LabelRowMapper.toLabelEntity(
        LabelRow(
          id: id,
          label: label,
          reference: reference,
          type: category,
          origin: origin,
        ),
      );
    } on LabelValidationException {
      return null;
    }
  }

  bool sameAttribution(NewLabel other, LabelBackupScope scope) =>
      labelEntity()?.type == other.type &&
      _resolveOrigin(origin, scope.allWallets) == other.origin;

  bool exactlyMatches(NewLabel other) =>
      labelEntity()?.type == other.type && origin == other.origin;
}

final class _LabelWrites {
  final int applied;
  final int unchanged;
  final Map<LabelRejection, int> rejected;

  const _LabelWrites(this.applied, this.unchanged, this.rejected);
}

final class _StalePlan implements Exception {
  const _StalePlan();
}

String? _resolveOrigin(String? origin, Set<String> wallets) {
  if (origin == null) return null;
  if (wallets.contains(origin)) return origin;
  final normalized = origin.replaceAll("'", 'h');
  final matches = wallets.where(
    (id) => bip329OriginFromWalletId(id) == normalized,
  );
  return matches.length == 1 ? matches.single : null;
}

String? _incomingWallet(BackupLabelRecord record, LabelBackupScope scope) {
  final wallet =
      record.walletId ?? _resolveOrigin(record.origin, scope.allWallets);
  return scope.wallets[wallet] == record.chain ? wallet : null;
}

Map<_LabelKey, List<LabelEntity>> _localLabels(
  List<_StoredLabel> rows,
  LabelBackupScope scope,
) {
  final local = <_LabelKey, List<LabelEntity>>{};
  for (final row in rows) {
    final label = row.labelEntity();
    if (label == null || LabelSystem.isSystemLabel(label.label)) continue;
    final wallet = _resolveOrigin(label.origin, scope.allWallets);
    final chain = scope.wallets[wallet];
    if (chain == null || wallet == null) continue;
    (local[(chain, _backupType(label.type), label.reference)] ??= []).add(
      LabelEntity(
        id: label.id,
        type: label.type,
        label: label.label,
        reference: label.reference,
        origin: wallet,
      ),
    );
  }
  return local;
}

String? _conflictWallet(
  Map<_LabelKey, List<LabelEntity>> local,
  LabelConflict conflict,
) {
  return local[(conflict.chain, conflict.type, conflict.ref)]
      ?.where((label) => label.label == conflict.localLabel)
      .firstOrNull
      ?.origin;
}

String _digest(Iterable<_StoredLabel> rows, LabelBackupScope scope) {
  final wallets = scope.wallets.keys.toList()..sort();
  return sha256
      .convert(
        utf8.encode(
          jsonEncode([
            [
              for (final id in wallets) [id, scope.wallets[id]?.name],
            ],
            [
              for (final row in rows)
                [row.label, row.reference, row.type, row.origin],
            ],
          ]),
        ),
      )
      .toString();
}

BackupLabelType _backupType(LabelType type) => switch (type) {
  LabelType.transaction => BackupLabelType.tx,
  LabelType.address => BackupLabelType.addr,
  LabelType.publicKey => BackupLabelType.pubkey,
  LabelType.input => BackupLabelType.input,
  LabelType.output => BackupLabelType.output,
  LabelType.extendedPublicKey => BackupLabelType.xpub,
};

LabelType _labelType(BackupLabelType type) => switch (type) {
  BackupLabelType.tx => LabelType.transaction,
  BackupLabelType.addr => LabelType.address,
  BackupLabelType.pubkey => LabelType.publicKey,
  BackupLabelType.input => LabelType.input,
  BackupLabelType.output => LabelType.output,
  BackupLabelType.xpub => LabelType.extendedPublicKey,
};
