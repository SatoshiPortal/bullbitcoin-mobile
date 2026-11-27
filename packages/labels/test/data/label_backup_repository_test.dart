import 'package:labels/backup.dart';
import 'package:labels/labels.dart';
import 'package:labels/labels_table.dart';
import 'package:labels/labels_table.drift.dart';
import 'package:labels/frozen_utxos_table.drift.dart';
import 'package:labels/src/data/label_backup_repository.dart';
import 'package:labels/src/data/labels_database.dart';
import 'package:labels/src/domain/wallet_freeze_port.dart';
import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _bitcoin = 'wpkh([aabbccdd/84h/0h/0h])';
const _liquid = 'elwpkh([aabbccdd/84h/1776h/0h])';
const _other = 'wpkh([dddddddd/84h/0h/0h])';
final _tx = '1' * 64;
final _otherTx = '2' * 64;

void main() {
  late LabelsDatabase db;
  late LabelBackupRepository adapter;
  late _FreezeStore freezes;

  final group = LabelBackupScope(
    groupId: 'group',
    bitcoinWalletIds: [_bitcoin],
    liquidWalletIds: [_liquid],
    allWalletIds: [_bitcoin, _liquid, _other],
  );
  final choices = MergeChoices({});
  setUp(() {
    db = LabelsDatabase(NativeDatabase.memory());
    freezes = _FreezeStore(db);
    adapter = LabelBackupRepository(database: db, walletFreeze: freezes);
  });
  tearDown(() => db.close());

  Future<void> addLabel(
    String text,
    String ref, {
    String? wallet,
    LabelTypeColumn type = LabelTypeColumn.tx,
  }) => db
      .into(db.labelsTable)
      .insert(
        LabelsTableCompanion.insert(
          label: text,
          reference: ref,
          type: type,
          origin: Value(wallet),
        ),
      );

  Future<MergePlan> plan(List<BackupLabelRecord> records) async => _ok(
    await adapter.preview(
      group,
      LabelsSnapshot(records: records, unattributedCount: 0, skippedCount: 0),
    ),
  );

  test(
    'captures both chains and counts only unattributed or unreadable rows',
    () async {
      await addLabel('memo', _tx, wallet: _bitcoin);
      await addLabel(
        'Liquid memo',
        '$_tx:0',
        type: LabelTypeColumn.output,
        wallet: _liquid,
      );
      await addLabel('other group', _tx, wallet: _other);
      await addLabel('no wallet', _tx);
      await addLabel('unreadable reference', 'short', wallet: _bitcoin);
      await db.customStatement(
        "INSERT INTO labels (label, reference, type) VALUES ('legacy', ?, 'bad_type')",
        [_tx],
      );
      await freezes.freeze([
        (walletId: _liquid, txId: _tx, vout: 0),
        (walletId: _bitcoin, txId: _tx, vout: 1),
        (walletId: _other, txId: _tx, vout: 2),
      ]);

      final snapshot = _ok(await adapter.capture(group));
      expect(snapshot.unattributedCount, 1);
      expect(snapshot.skippedCount, 2);
      expect(
        snapshot.records.map(
          (r) => (r.chain, r.walletId, r.label, r.spendable),
        ),
        unorderedEquals([
          (BackupLabelChain.bitcoin, _bitcoin, 'memo', null),
          (BackupLabelChain.liquid, _liquid, 'Liquid memo', false),
          (BackupLabelChain.bitcoin, _bitcoin, null, false),
        ]),
      );
    },
  );

  test('emits change hints for label and freeze writes', () async {
    await db.select(db.labelsTable).get();
    final labelChange = adapter.changes.first;
    await addLabel('memo', _tx, wallet: _bitcoin);
    await labelChange.timeout(const Duration(seconds: 5));

    final freezeChange = adapter.changes.first;
    await freezes.freeze([(walletId: _bitcoin, txId: _tx, vout: 0)]);
    await freezeChange.timeout(const Duration(seconds: 5));
  });

  test('refuses a stale plan before either channel writes', () async {
    final preview = await plan([_label('new', _tx), _freeze(_bitcoin, _tx)]);
    await addLabel('concurrent edit', _otherTx, wallet: _bitcoin);
    freezes.owned[_bitcoin] = {(txId: _tx, vout: 0)};

    expect(
      await adapter.apply(group, preview, choices),
      isA<Err<ApplyReport, LabelFailure>>().having(
        (err) => err.failure,
        'failure',
        isA<LabelBackupStalePlanFailure>(),
      ),
    );
    expect(await db.select(db.labelsTable).get(), hasLength(1));
    expect(freezes.checked, isEmpty);
    expect(await db.select(db.frozenUtxos).get(), isEmpty);
  });

  test('rejects reserved labels after sanitizing and leaves foreign SQL rows intact', () async {
    await addLabel('existing', _tx, wallet: _other);
    final preview = await plan([
      _label(' s\u0000waps ', _tx),
      _label('existing', _tx),
      _label('unknown wallet', _tx, wallet: _other),
    ]);

    final report = _ok(await adapter.apply(group, preview, choices));
    expect(report.labelsApplied, 0);
    expect(report.labelsRejected, {
      LabelRejection.reservedLabel: 1,
      LabelRejection.notOwned: 2,
    });
    final row = await db.select(db.labelsTable).getSingle();
    expect(row.label, 'existing');
    expect(row.origin, _other);
  });

  test(
    'uses the attributed wallet only and retries missing outputs additively',
    () async {
      final preview = await plan([
        _label('memo', _tx),
        _freeze(_bitcoin, _tx),
        _freeze(_other, _otherTx),
      ]);
      final pending = FreezeRequest(walletId: _bitcoin, outpoint: '$_tx:0');
      final foreign = FreezeRequest(walletId: _other, outpoint: '$_otherTx:0');
      freezes.owned[_liquid] = {(txId: _tx, vout: 0)};
      freezes.owned[_other] = {(txId: _otherTx, vout: 0)};
      final first = _ok(await adapter.apply(group, preview, choices));
      expect(first.labelsApplied, 1);
      expect(first.freezes, {
        pending: FreezeOutcome.pendingDiscovery,
        foreign: FreezeOutcome.notOwned,
      });
      expect(freezes.checked, [_bitcoin]);
      expect(await db.select(db.frozenUtxos).get(), isEmpty);

      freezes.owned[_bitcoin] = {(txId: _tx, vout: 0)};
      for (var count = 0; count < 2; count++) {
        final report = _ok(await adapter.apply(group, preview, choices));
        expect(report.labelsApplied, 0);
        expect(report.labelsUnchanged, 1);
        expect(report.freezes, {
          pending: FreezeOutcome.applied,
          foreign: FreezeOutcome.notOwned,
        });
        freezes.owned.clear();
      }
      expect(await db.select(db.labelsTable).get(), hasLength(1));
      final row = await db.select(db.frozenUtxos).getSingle();
      expect((row.walletId, row.txId, row.vout), (_bitcoin, _tx, 0));
    },
  );

  test('reports freeze failures after committing labels and continues with the next outpoint', () async {
    final preview = await plan([
      _label('memo', _tx),
      _freeze(_bitcoin, _tx),
      _freeze(_bitcoin, _otherTx),
    ]);
    freezes.owned[_bitcoin] = {(txId: _tx, vout: 0), (txId: _otherTx, vout: 0)};
    freezes.failTx = _tx;

    final report = _ok(await adapter.apply(group, preview, choices));
    expect(report.labelsApplied, 1);
    expect(report.freezes, {
      FreezeRequest(walletId: _bitcoin, outpoint: '$_tx:0'):
          FreezeOutcome.failed,
      FreezeRequest(walletId: _bitcoin, outpoint: '$_otherTx:0'):
          FreezeOutcome.applied,
    });
    expect((await db.select(db.labelsTable).getSingle()).label, 'memo');
    expect((await db.select(db.frozenUtxos).getSingle()).txId, _otherTx);
  });

  // A withdrawn authorization:
  {
    LabelBackupScope scopeWith(bool Function() authority) => LabelBackupScope(
      groupId: 'group',
      bitcoinWalletIds: [_bitcoin],
      liquidWalletIds: [_liquid],
      allWalletIds: [_bitcoin, _liquid, _other],
      authority: authority,
    );

    /// Answers from [answers] in order, then keeps the last one.
    bool Function() sequence(List<bool> answers) {
      var next = 0;
      return () => answers[next < answers.length ? next++ : answers.length - 1];
    }

    test(
      'authorization withdrawn before the transaction writes nothing',
      () async {
        final preview = await plan([_label('memo', _tx)]);
        final result = await adapter.apply(
          scopeWith(() => false),
          preview,
          choices,
        );
        expect(
          result,
          isA<Err<ApplyReport, LabelFailure>>().having(
            (error) => error.failure,
            'failure',
            isA<LabelBackupRevokedFailure>(),
          ),
        );
        expect(await db.select(db.labelsTable).get(), isEmpty);
      },
    );

    test(
      'authorization withdrawn inside the transaction rolls every label back',
      () async {
        final preview = await plan([_label('memo', _tx)]);
        // Allowed at the start, withdrawn just before the commit.
        final result = await adapter.apply(
          scopeWith(sequence([true, false])),
          preview,
          choices,
        );
        expect(result, isA<Err<ApplyReport, LabelFailure>>());
        expect(await db.select(db.labelsTable).get(), isEmpty);
      },
    );

    test(
      'authorization withdrawn during the ownership check freezes nothing',
      () async {
        final preview = await plan([_freeze(_bitcoin, _tx)]);
        freezes.owned[_bitcoin] = {(txId: _tx, vout: 0)};
        var allowed = true;
        // The withdrawal lands while the wallet verifies the coin it holds.
        freezes.onOwnedCheck = () => allowed = false;
        final report = _ok(
          await adapter.apply(scopeWith(() => allowed), preview, choices),
        );
        expect(report.freezes.values, [FreezeOutcome.failed]);
        expect(await db.select(db.frozenUtxos).get(), isEmpty);
      },
    );

    test('authorization withdrawn between two freezes stops the next one and reports it', () async {
      final preview = await plan([
        _freeze(_bitcoin, _tx),
        _freeze(_bitcoin, _otherTx),
      ]);
      freezes.owned[_bitcoin] = {
        (txId: _tx, vout: 0),
        (txId: _otherTx, vout: 0),
      };
      // Start, commit and the whole first freeze (asked before it and again
      // just before the write) are allowed; the second is not.
      final report = _ok(
        await adapter.apply(
          scopeWith(sequence([true, true, true, true, false])),
          preview,
          choices,
        ),
      );
      expect(report.freezes.values, [
        FreezeOutcome.applied,
        FreezeOutcome.failed,
      ]);
      expect((await db.select(db.frozenUtxos).get()).map((r) => r.txId), [_tx]);
    });
  }

  test('keeps local conflicts by default and adds selected backups without deletion', () async {
    await addLabel('local', _tx, wallet: _bitcoin);
    final preview = await plan([
      _label('backup', _tx),
      _label('also backed up', _tx),
    ]);
    final conflict = preview.conflicts.single;
    expect(
      (conflict.chain, conflict.type, conflict.ref),
      (BackupLabelChain.bitcoin, BackupLabelType.tx, _tx),
    );
    expect(_ok(await adapter.apply(group, preview, choices)).labelsApplied, 0);
    final selected = MergeChoices({conflict: ConflictResolution.useBackup});
    expect(_ok(await adapter.apply(group, preview, selected)).labelsApplied, 2);
    expect(
      (await db.select(db.labelsTable).get()).map((row) => row.label),
      unorderedEquals(['local', 'backup', 'also backed up']),
    );
    expect(_ok(await adapter.apply(group, preview, selected)).labelsApplied, 0);
  });
  test(
    'conflict choices are independent for the same reference on each chain',
    () async {
      await addLabel('Bitcoin local', _tx, wallet: _bitcoin);
      await addLabel('Liquid local', _tx, wallet: _liquid);
      final preview = await plan([
        _label('Bitcoin backup', _tx),
        BackupLabelRecord(
          chain: BackupLabelChain.liquid,
          type: BackupLabelType.tx,
          ref: _tx,
          label: 'Liquid backup',
          walletId: _liquid,
        ),
      ]);
      expect(preview.conflicts.toSet(), hasLength(2));
      final liquid = preview.conflicts.singleWhere(
        (conflict) => conflict.chain == BackupLabelChain.liquid,
      );
      final report = _ok(
        await adapter.apply(
          group,
          preview,
          MergeChoices({liquid: ConflictResolution.useBackup}),
        ),
      );
      expect(report.labelsApplied, 1);
      expect(
        (await db.select(db.labelsTable).get()).map(
          (row) => (row.label, row.origin),
        ),
        unorderedEquals([
          ('Bitcoin local', _bitcoin),
          ('Liquid local', _liquid),
          ('Liquid backup', _liquid),
        ]),
      );
    },
  );
}

BackupLabelRecord _label(
  String label,
  String ref, {
  String wallet = _bitcoin,
}) => BackupLabelRecord(
  chain: BackupLabelChain.bitcoin,
  type: BackupLabelType.tx,
  ref: ref,
  label: label,
  walletId: wallet,
);

BackupLabelRecord _freeze(String walletId, String tx) => BackupLabelRecord(
  chain: BackupLabelChain.bitcoin,
  type: BackupLabelType.output,
  ref: '$tx:0',
  spendable: false,
  walletId: walletId,
);

T _ok<T>(Result<T, LabelFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('Unexpected ${failure.runtimeType}'),
};

final class _FreezeStore implements WalletFreezePort {
  final LabelsDatabase _db;
  final owned = <String, Set<({String txId, int vout})>>{};
  final checked = <String>[];
  String? failTx;

  /// Runs while ownership is being verified, just before the freeze.
  void Function()? onOwnedCheck;

  _FreezeStore(this._db);

  @override
  Future<void> freeze(
    List<({String? walletId, String txId, int vout})> outputs,
  ) async {
    for (final output in outputs) {
      if (output.txId == failTx) throw const FormatException('Unavailable');
      await _db
          .into(_db.frozenUtxos)
          .insert(
            FrozenUtxosCompanion.insert(
              walletId: output.walletId ?? '',
              txId: output.txId,
              vout: output.vout,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  @override
  Future<List<({String walletId, String txId, int vout})>>
  getAllFrozen() async => [
    for (final row in await _db.select(_db.frozenUtxos).get())
      (walletId: row.walletId, txId: row.txId, vout: row.vout),
  ];

  @override
  Future<List<({String txId, int vout})>> getOwnedOutpoints({
    required String walletId,
  }) async {
    checked.add(walletId);
    onOwnedCheck?.call();
    return owned[walletId]?.toList() ?? [];
  }
}
