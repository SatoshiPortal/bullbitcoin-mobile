// One-shot LOCAL artifact builder. Never receives or opens a source database.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ark/ark.dart';
import 'package:ark/ark_sql.dart';
import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

const sourcePin = '303682063ed7559b06dcf37c5cb37bb7037b943f';
const maxFieldBytes = 1024 * 1024;

void require(bool condition) {
  if (!condition) {
    throw const FormatException('Fixture evidence refused');
  }
}

Map<String, dynamic> object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected object');
  }
  return value;
}

String text(Object? value) {
  if (value is! String || value.isEmpty) {
    throw const FormatException('Expected nonempty text');
  }
  return value;
}

DateTime instant(Object? value) {
  final encoded = text(value);
  require(encoded.endsWith('Z'));
  return DateTime.parse(encoded);
}

bool same(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && same(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        Iterable<int>.generate(a.length).every((i) => same(a[i], b[i]));
  }
  return a.runtimeType == b.runtimeType && a == b;
}

Uint8List material(Object? raw, Object? descriptor) {
  require(raw is List && raw.isNotEmpty && raw.length <= maxFieldBytes);
  final values = raw as List;
  require(values.every((v) => v is int && v >= 0 && v <= 255));
  final bytes = Uint8List.fromList(values.cast<int>());
  final expected = object(descriptor);
  require(expected['byteLength'] is int);
  require(bytes.length == expected['byteLength']);
  require(sha256.convert(bytes).toString() == text(expected['sha256']));
  return bytes;
}

T found<T>(Result<ArkSqlRead<T>, ArkWalletFailure> result) {
  if (result case Ok(value: ArkSqlFound<T>(:final value))) {
    return value;
  }
  throw const FormatException('Public guarded read refused fixture');
}

Future<void> main(List<String> args) async {
  // Paths only: bundle JSON, independently recorded expected JSON, NEW output.
  require(args.length == 3);
  final bundleFile = File(args[0]);
  final expectedFile = File(args[1]);
  require(bundleFile.lengthSync() <= 32 * 1024 * 1024);
  require(expectedFile.lengthSync() <= maxFieldBytes);
  final bundle = object(jsonDecode(bundleFile.readAsStringSync()));
  final expectedBytes = expectedFile.readAsBytesSync();
  final independent = object(jsonDecode(utf8.decode(expectedBytes)));
  require(bundle['status'] == 'REAL_CAPTURED_AND_REVIEWED');
  require(bundle['materialPresent'] == true);
  require(bundle['schemaRevision'] is int && bundle['schemaRevision'] == 42);
  require(
    sha256.convert(expectedBytes).toString() ==
        bundle['prebuildExpectedManifestSha256'],
  );
  for (final key in [
    'publicIdentity',
    'sourceExpected',
    'sourceGrantReference',
    'sourceExpectedRecordedAtUtc',
  ]) {
    require(same(bundle[key], independent[key]));
  }
  final builderFacts = object(bundle['builderOutput']);
  final review = text(builderFacts['secretReviewReference']);
  text(bundle['sourceGrantReference']);
  final now = DateTime.now().toUtc();
  require(instant(bundle['sourceHandlesClosedAtUtc']).isBefore(now));
  require(instant(bundle['sourceExpectedRecordedAtUtc']).isBefore(now));
  final identity = object(bundle['publicIdentity']);
  require(identity['testNamespaceIsParentAuthentication'] == false);
  final expected = object(independent['sourceExpected']);
  final rows = object(bundle['selectedRecords']);
  final vtxo = object(rows['vtxo']);
  final exit = object(rows['exit']);
  final child = object(rows['child']);
  final properties = object(rows['publicProperties']);
  final vtxoId = text(expected['vtxoId']);
  final parent = text(expected['parentTxid']);
  require(vtxo['id'] == vtxoId && exit['vtxoId'] == vtxoId);
  require(child['exitId'] == parent);
  require(exit['sourceMovementIdWasNull'] is bool);
  require(properties['id'] == '1' && properties['network'] == 'regtest');
  require(properties['fingerprint'] == identity['nativeFingerprint']);
  require(properties['serverPubkey'] == identity['serverPubkey']);
  final bare = material(vtxo['rawBareBytes'], expected['rawBare']);
  final genesis = material(vtxo['rawGenesisBytes'], expected['rawGenesis']);
  final childBytes = material(
    child['childTransactionBytes'],
    expected['childTransaction'],
  );
  final state = utf8.decode(
    material(exit['stateUtf8Bytes'], expected['stateUtf8']),
  );
  final history = utf8.decode(
    material(exit['historyUtf8Bytes'], expected['historyUtf8']),
  );
  final origin = utf8.decode(
    material(child['originUtf8Bytes'], expected['originUtf8']),
  );
  // Strict UTF8 decode above: do NOT JSON re-encode stored source strings.
  require(jsonDecode(history) is List);
  final package = Isolate.resolvePackageUriSync(
    Uri.parse('package:ark/ark.dart'),
  );
  if (package == null) {
    throw StateError('Missing Ark package mapping');
  }
  final ddlFile = File.fromUri(
    package.resolve('../test/fixtures/bark_schema42.sql'),
  );
  final ddlBytes = ddlFile.readAsBytesSync();
  require(sha256.convert(ddlBytes).toString() == ddlSha256);
  final destination = Directory(args[2]);
  require(!destination.existsSync());
  destination.createSync();
  var completed = false;
  try {
    final fixture = File('${destination.path}/material.sqlite');
    final db = sqlite3.open(fixture.path);
    try {
      db.execute('PRAGMA foreign_keys=ON');
      db.execute(utf8.decode(ddlBytes));
      db.execute('BEGIN');
      db.execute('INSERT INTO migrations(value) VALUES(?)', [42]);
      db.execute(
        'INSERT INTO bark_properties(id,network,fingerprint,server_pubkey) VALUES(?,?,?,?)',
        ['1', 'regtest', properties['fingerprint'], properties['serverPubkey']],
      );
      db.execute(
        'INSERT INTO bark_vtxo(id,raw_bare,raw_genesis) VALUES(?,?,?)',
        [vtxoId, bare, genesis],
      );
      db.execute(
        'INSERT INTO bark_exit_states(vtxo_id,state,history,movement_id) VALUES(?,?,?,NULL)',
        [vtxoId, state, history],
      );
      db.execute(
        'INSERT INTO bark_exit_child_transactions(exit_id,child_tx,tx_origin) VALUES(?,?,?)',
        [parent, childBytes, origin],
      );
      db.execute('COMMIT');
      require(db.select('PRAGMA integrity_check').single.values.single == 'ok');
      require(db.select('PRAGMA foreign_key_check').isEmpty);
    } finally {
      db.close();
    }
    final repo = createArkSqlExitRepository(
      databasePath: fixture.path,
      account: ArkAccountId(
        parent: Fingerprint(text(identity['testNamespaceFingerprint'])),
        network: BitcoinNetwork.regtest,
        serverIdentity: text(identity['serverIdentity']),
      ),
      expectedNativeFingerprint: text(identity['nativeFingerprint']),
      expectedServerPubkey: text(identity['serverPubkey']),
    );
    final storedVtxo = found(await repo.readVtxo(vtxoId: vtxoId));
    require(
      same(storedVtxo.rawBare, bare) && same(storedVtxo.rawGenesis, genesis),
    );
    final storedState = found(await repo.readExitState(vtxoId: vtxoId));
    require(storedState.phase == ArkSqlExitPhase.processing);
    final refs = storedState.transactionRefs
        .where((r) => r.parentTxid == parent)
        .toList();
    require(refs.length == 1);
    require(refs.single.phase.name == expected['transactionPhase']);
    require(refs.single.childTxid == expected['recordedChildTxid']);
    final storedChild = found(await repo.readExitChild(parentTxid: parent));
    require(same(storedChild.transactionBytes, childBytes));
    require(storedChild.origin.name == expected['childOrigin']);
    require(storedChild.confirmedIn?.height == expected['confirmedHeight']);
    require(storedChild.confirmedIn?.hash == expected['confirmedHash']);
    final provenance = <String, Object?>{
      'status': 'REAL_CAPTURED_AND_REVIEWED',
      'barkCommit': sourcePin,
      'flow': 'dedicated-non-htlc-board',
      'sourceGrantReference': bundle['sourceGrantReference'],
      'sourceExpectedRecordedAtUtc': bundle['sourceExpectedRecordedAtUtc'],
      'sourceHandlesClosedAtUtc': bundle['sourceHandlesClosedAtUtc'],
      'fixtureBuildStartedAtUtc': now.toIso8601String(),
      'prebuildExpectedManifestSha256':
          bundle['prebuildExpectedManifestSha256'],
      'secretReviewReference': review,
      'fixtureSha256': sha256.convert(fixture.readAsBytesSync()).toString(),
      'movementIdSanitizedToNull': true,
      'sourceMovementIdWasNull': exit['sourceMovementIdWasNull'],
      'otherSummaryColumnsPolicy': 'Only id/raw_bare/raw_genesis inserted; expiry_height/amount_sat/exit_depth/exit_tx_weight NULL; registered=0; created_at=local DDL default; public properties mailbox=NULL',
      'publicIdentity': identity,
      'sourceExpected': expected,
    };
    File('${destination.path}/provenance.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(provenance)}\n',
      flush: true,
    );
    completed = true;
    stdout.writeln(
      'Local fixture built; external expected-manifest and secret review remain publication gates.',
    );
  } finally {
    if (!completed) {
      destination.deleteSync(recursive: true);
    }
  }
}

const ddlSha256 =
    '3b7a043aa407fa93841354d7a72dc96ba2aa2bdc9d4be9b76c56825ec26fdded';
