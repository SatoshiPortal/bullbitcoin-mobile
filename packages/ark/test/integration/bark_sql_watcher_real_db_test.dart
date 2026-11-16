import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ark/ark.dart';
import 'package:ark/src/data/exit_archive/ark_exit_archive.dart';
import 'package:ark/src/data/exit_archive/bark_sql_observer.dart';
import 'package:ark/src/data/exit_archive/bark_sql_schema.dart';
import 'package:ark/src/data/exit_archive/sqlite_exit_archive.dart';
import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

// Independent reviewed query manifest. No source mutations or native opener.
const queries = {
  'bark_properties': [
    'id',
    'network',
    'fingerprint',
    'server_pubkey',
    'server_mailbox_pubkey',
  ],
  'bark_vtxo': [
    'id',
    'raw_bare',
    'raw_genesis',
    'expiry_height',
    'amount_sat',
    'registered',
  ],
  'bark_vtxo_state': ['id', 'vtxo_id', 'state_kind', 'state'],
  'bark_wallet_action_checkpoint': ['id', 'payload'],
  'bark_vtxo_key': ['public_key', 'idx'],
  'bark_pending_lightning_receive': [
    'payment_hash',
    'preimage',
    'invoice',
    'htlc_vtxo_ids',
    'finished_at',
  ],
  'bark_settled_lightning_receive': [
    'payment_hash',
    'preimage',
    'invoice',
    'amount_sat',
  ],
  'bark_exit_states': ['vtxo_id', 'state', 'history', 'movement_id'],
  'bark_exit_child_transactions': ['exit_id', 'child_tx', 'tx_origin'],
};

void check(bool condition, String message) {
  // Never pass secret-bearing actual/expected values to a test matcher.
  if (!condition) throw StateError(message);
}

T value<T>(Result<T, ArkWalletFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(
    'Typed refusal ${failure.runtimeType}/${failure.reason.name}',
  ),
};

Object tagged(Object? cell) => switch (cell) {
  null => ['null'],
  String text => ['text', text],
  int integer => ['integer', integer.toString()],
  Uint8List bytes => [
    'blob',
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
  ],
  _ => throw StateError('Unexpected SQLite runtime type'),
};

Map<String, Object?> fileFacts(String path) {
  final file = File(path);
  if (!file.existsSync()) return {'exists': false};
  final stat = file.statSync();
  return {
    'exists': true,
    'size': stat.size,
    'modifiedUTC': stat.modified.toUtc().toIso8601String(),
    'mode': stat.mode,
    'sha256': sha256.convert(file.readAsBytesSync()).toString(),
  };
}

Map<String, Object?> sourceFacts(String path) => {
  for (final suffix in ['', '-wal', '-shm', '-journal'])
    suffix: fileFacts('$path$suffix'),
};

final class _LiveSnapshotsDiffer implements Exception {}

void compareSnapshots(bool condition, String _) {
  if (!condition) throw _LiveSnapshotsDiffer();
}

void main() {
  final publicManifest = Platform.environment['ARK_REAL_DB_MANIFEST'];
  final output = Platform.environment['ARK_REAL_DB_REPORT_DIR'];
  test(
    'actual Bark SQL observer retains real rows and preserves dirty state',
    () async {
      check(
        publicManifest != null && output != null,
        'Explicit authorized manifest/report paths required',
      );
      if (publicManifest == null || output == null) return;
      final manifest = jsonDecode(
        File(publicManifest).readAsStringSync(),
      ) as Map<String, dynamic>;
      final window = manifest['read_window'] as Map<String, dynamic>;
      final end = DateTime.parse(window['end'] as String);
      final start = DateTime.parse(window['start'] as String);
      check(
        DateTime.now().isAfter(start) && DateTime.now().isBefore(end),
        'Authorized read window is not open',
      );
      final reports = <Object>[];
      for (final item in manifest['wallets'] as List) {
        check(DateTime.now().isBefore(end), 'Authorized read window ended');
        final fixture = item as Map<String, dynamic>;
        final source = fixture['path'] as String;
        check(
          fixture['network'] == 'regtest' && fixture['schema'] == 42,
          'Trusted provenance must be regtest/schema42',
        );
        // Stack CLI has no host BIP85 identity. This is ONLY a private test namespace.
        final account = ArkAccountId(
          parent: Fingerprint(fixture['fingerprint'] as String),
          network: BitcoinNetwork.regtest,
          serverIdentity: fixture['server_pubkey'] as String,
        );
        final schema = BarkSqlSchema(
          account,
          fixture['fingerprint'] as String,
          fixture['server_pubkey'] as String,
        );
        final before = sourceFacts(source);
        final own = Directory.systemTemp.createTempSync('ark-real-sql-check-');
        final archivePath = '${own.path}/archive.sqlite';
        final observer = SqliteBarkObserver(sourcePath: source, schema: schema);
        SqliteExitArchive? archive;
        Database? reference;
        var phase = 'read actual observer';
        try {
          final observation = value(await observer.read());
          check(
            observation.account == account,
            'Observation identity mismatch',
          );
          check(
            observation.sourceToken.epochConn > 0 &&
                observation.sourceToken.dataVersion > 0,
            'Invalid process-local token',
          );
          check(
            observation.observedAtUTC.isUtc,
            'Observation timestamp is not UTC',
          );
          phase = 'independent readonly snapshot';
          final db = sqlite3.open(source, mode: OpenMode.readOnly);
          reference = db;
          db.execute('PRAGMA query_only=ON');
          db.execute('PRAGMA busy_timeout=0');
          db.execute('BEGIN');
          final counts = <String, int>{};
          final seen = <String>{};
          try {
            check(
              db
                      .select('SELECT MAX(value) FROM migrations')
                      .single
                      .values
                      .single ==
                  42,
              'Native migration mismatch',
            );
            for (final entry in queries.entries) {
              final expected = db.select(
                'SELECT ${entry.value.join(',')} FROM ${entry.key} ORDER BY ${entry.value.first}',
              );
              final actual = observation.rows
                  .where((r) => r.sourceTable == entry.key)
                  .toList();
              compareSnapshots(
                actual.length == expected.length,
                'Live snapshots differ in row counts; comparison inconclusive',
              );
              counts[entry.key] = expected.length;
              for (var i = 0; i < expected.length; i++) {
                final row = actual[i];
                final payload = jsonDecode(row.payload) as List;
                check(
                  payload.length == 9 && payload[0] == 'bark-sql-row-v1',
                  'Opaque payload structure mismatch',
                );
                check(
                  payload[1] == BarkSqlSchema.sourceSchemaId &&
                      payload[2] == account.canonical,
                  'Opaque provenance mismatch',
                );
                check(
                  payload[3] == fixture['fingerprint'] &&
                      payload[4] == fixture['server_pubkey'],
                  'Opaque public identity mismatch',
                );
                check(
                  payload[5] == BarkSqlSchema.layoutDigest &&
                      payload[6] == entry.key,
                  'Opaque layout/table mismatch',
                );
                final cells = payload[8] as List;
                check(
                  cells.length == entry.value.length,
                  'Opaque column count mismatch',
                );
                for (var c = 0; c < entry.value.length; c++) {
                  final cell = cells[c] as List;
                  check(
                    cell.length == 2 && cell[0] == entry.value[c],
                    'Opaque column order mismatch',
                  );
                  compareSnapshots(
                    jsonEncode(cell[1]) ==
                        jsonEncode(tagged(expected[i][entry.value[c]])),
                    'Live snapshots differ in cells; comparison inconclusive',
                  );
                }
                check(
                  row.rowKey ==
                      jsonEncode(tagged(expected[i][entry.value.first])),
                  'Opaque row key mismatch',
                );
                check(
                  jsonEncode(payload[7]) == row.rowKey,
                  'Opaque payload key mismatch',
                );
                check(
                  jsonEncode(payload) == row.payload,
                  'Opaque payload is not canonical',
                );
                check(
                  sha256.convert(utf8.encode(row.payload)).toString() ==
                      row.digest,
                  'Opaque SHA256 mismatch',
                );
                check(
                  seen.add(jsonEncode([row.sourceTable, row.rowKey])),
                  'Duplicate opaque row',
                );
              }
            }
          } finally {
            db.execute('ROLLBACK');
            db.close();
            reference = null;
          }
          check(
            seen.length == observation.rows.length,
            'Unexpected observed table rows',
          );
          check(
            (counts['bark_properties'] ?? 0) == 1,
            'Missing real properties',
          );
          check(
            (counts['bark_vtxo'] ?? 0) > 0 &&
                (counts['bark_vtxo_key'] ?? 0) > 0,
            'Real populated VTXO/key evidence required',
          );
          phase = 'own archive persistence and dirty preservation';
          final opened = value(
            SqliteExitArchive.open(
              archivePath,
              account,
              create: true,
              sqlSchema: schema,
            ),
          );
          archive = opened;
          final intent = value(
            await opened.begin(ArkExitCaptureStage.synchronize),
          );
          check(
            value(await opened.appendSqlObservation(observation)),
            'Initial opaque append did not change own archive',
          );
          check(
            !value(await opened.appendSqlObservation(observation)),
            'Identical opaque append is not idempotent',
          );
          final view = value(await opened.read());
          check(
            view.state == ArkExitCaptureState.dirty &&
                view.acknowledgedThrough == 0,
            'Opaque reads changed capture authority',
          );
          check(
            view.pending.length == 1 && view.pending.single.matches(intent),
            'Opaque append changed pending intent',
          );
          check(
            view.proofs.isEmpty &&
                view.material.isEmpty &&
                view.issues.contains(
                  ArkExitCaptureIssue.nativeCoverageUnavailable,
                ),
            'Opaque rows fabricated complete proofs/material',
          );
          await opened.close();
          archive = null;
          final stored = sqlite3.open(archivePath, mode: OpenMode.readOnly);
          try {
            stored.execute('PRAGMA query_only=ON');
            final rows = stored.select(
              'SELECT source_table,row_key,payload,digest FROM opaque_sql_rows',
            );
            check(
              rows.length == observation.rows.length,
              'Persisted opaque count mismatch',
            );
            for (final row in rows) {
              final matches = observation.rows.where(
                (r) =>
                    r.sourceTable == row['source_table'] &&
                    r.rowKey == row['row_key'],
              );
              check(matches.length == 1, 'Persisted row binding mismatch');
              check(
                matches.single.payload == row['payload'] &&
                    matches.single.digest == row['digest'],
                'Persisted opaque bytes changed',
              );
            }
          } finally {
            stored.close();
          }
          final reopened = value(
            SqliteExitArchive.open(
              archivePath,
              account,
              create: false,
              sqlSchema: schema,
            ),
          );
          archive = reopened;
          check(
            !value(await reopened.appendSqlObservation(observation)),
            'Opaque dedup changed after reopen',
          );
          check(
            value(await reopened.read()).pending.single.matches(intent),
            'Pending intent changed after reopen',
          );
          phase = 'source metadata sample';
          await observer.close();
          final after = sourceFacts(source);
          // Metadata samples are observations only; live writers may change them.
          reports.add({
            'wallet': fixture['wallet'],
            'counts': counts,
            'rowsCompared': seen.length,
            'sourceBefore': before,
            'sourceAfter': after,
            'sidecarsStable': jsonEncode(before) == jsonEncode(after),
            'archivePersistenceIdempotenceDirtyPreserved': true,
            'hostParentLinkVerified': false,
            'fullWitnessRestoreVerified': false,
          });
        } on _LiveSnapshotsDiffer {
          markTestSkipped(
            'Independent live snapshots differed; comparison inconclusive',
          );
          return;
        } on Exception {
          throw StateError(
            'Real DB check failed during $phase; raw values suppressed',
          );
        } finally {
          reference?.close();
          await observer.close();
          await archive?.close();
          own.deleteSync(recursive: true);
        }
      }
      final report = File('$output/result.json');
      report.writeAsStringSync(
        jsonEncode({
          'observedAtUTC': DateTime.now().toUtc().toIso8601String(),
          'wallets': reports,
        }),
        flush: true,
      );
      check(DateTime.now().isBefore(end), 'Read window exceeded');
    },
    skip: publicManifest == null || output == null
        ? 'Requires an explicitly authorized real DB read window; not runtime evidence'
        : false,
  );
}
