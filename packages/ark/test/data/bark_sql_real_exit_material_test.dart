// Public SQL retrieval proof using reviewed saved regtest material.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:ark/ark.dart';
import 'package:ark/ark_sql.dart';
import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  test('reads saved real board exit material through all three public methods', () async {
    final package = Isolate.resolvePackageUriSync(
      Uri.parse('package:ark/ark.dart'),
    );
    if (package == null) {
      throw StateError('Missing Ark package URI');
    }
    final directory = package.resolve('../test/fixtures/bark_real_exit/');
    final provenanceFile = File.fromUri(directory.resolve('provenance.json'));
    final saved = File.fromUri(directory.resolve('material.sqlite'));
    // Deliberately mandatory: no skip, environment gate, or synthetic fallback.
    expect(provenanceFile.existsSync(), isTrue);
    expect(saved.existsSync(), isTrue);
    final manifest =
        jsonDecode(provenanceFile.readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['status'], 'REAL_CAPTURED_AND_REVIEWED');
    expect(manifest['barkCommit'], '303682063ed7559b06dcf37c5cb37bb7037b943f');
    expect(manifest['flow'], 'dedicated-non-htlc-board');
    expect(manifest['movementIdSanitizedToNull'], isTrue);
    final expected = manifest['sourceExpected'] as Map<String, dynamic>;
    final identity = manifest['publicIdentity'] as Map<String, dynamic>;
    final vtxoId = expected['vtxoId'] as String;
    final parentTxid = expected['parentTxid'] as String;
    expect(RegExp(r'^[0-9a-f]{64}:[0-9]+$').hasMatch(vtxoId), isTrue);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(parentTxid), isTrue);
    final sourceClosed = DateTime.parse(
      manifest['sourceHandlesClosedAtUtc'] as String,
    );
    final buildStarted = DateTime.parse(
      manifest['fixtureBuildStartedAtUtc'] as String,
    );
    final expectedRecorded = DateTime.parse(
      manifest['sourceExpectedRecordedAtUtc'] as String,
    );
    expect(sourceClosed.isBefore(buildStarted), isTrue);
    expect(expectedRecorded.isBefore(buildStarted), isTrue);
    expect(manifest['sourceGrantReference'], isA<String>());
    expect(manifest['secretReviewReference'], isA<String>());
    expect(
      manifest['prebuildExpectedManifestSha256'],
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );
    expect(
      sha256.convert(saved.readAsBytesSync()).toString(),
      manifest['fixtureSha256'],
    );

    final temporary = Directory.systemTemp.createTempSync(
      'ark-real-exit-unit-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final detached = saved.copySync('${temporary.path}/material.sqlite');
    final db = sqlite3.open(detached.path, mode: OpenMode.readOnly);
    try {
      db.execute('PRAGMA query_only=ON');
      expect(db.select('PRAGMA query_only').single.values.single, 1);
      expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
      expect(db.select('PRAGMA foreign_key_check'), isEmpty);
      final versions = db.select(
        'SELECT value, typeof(value) AS kind FROM migrations',
      );
      expect(versions, hasLength(1));
      expect(versions.single['value'], 42);
      expect(versions.single['kind'], 'integer');
      final allowedCounts = <String, int>{
        'migrations': 1,
        'bark_properties': 1,
        'bark_vtxo': 1,
        'bark_exit_states': 1,
        'bark_exit_child_transactions': 1,
      };
      for (final row in db.select(
        "SELECT name FROM sqlite_schema WHERE type='table'",
      )) {
        final name = row['name'] as String;
        if (name == 'sqlite_sequence') continue;
        final quoted = name.replaceAll('"', '""');
        expect(
          db.select('SELECT count(*) AS n FROM "$quoted"').single['n'],
          allowedCounts[name] ?? 0,
          reason: name,
        );
      }
      final state = db.select(
        'SELECT state, history, movement_id FROM bark_exit_states WHERE vtxo_id=?',
        [vtxoId],
      ).single;
      expect(state['movement_id'], isNull);
      bytesMatch(utf8.encode(state['state'] as String), expected['stateUtf8']);
      bytesMatch(
        utf8.encode(state['history'] as String),
        expected['historyUtf8'],
      );
      final origin = db.select(
        'SELECT tx_origin FROM bark_exit_child_transactions WHERE exit_id=?',
        [parentTxid],
      ).single;
      bytesMatch(
        utf8.encode(origin['tx_origin'] as String),
        expected['originUtf8'],
      );
    } finally {
      db.close();
    }

    final repository = createArkSqlExitRepository(
      databasePath: detached.path,
      account: ArkAccountId(
        parent: Fingerprint(identity['testNamespaceFingerprint'] as String),
        network: BitcoinNetwork.regtest,
        serverIdentity: identity['serverIdentity'] as String,
      ),
      expectedNativeFingerprint: identity['nativeFingerprint'] as String,
      expectedServerPubkey: identity['serverPubkey'] as String,
    );
    final components = found(await repository.readVtxo(vtxoId: vtxoId));
    final state = found(await repository.readExitState(vtxoId: vtxoId));
    final child = found(await repository.readExitChild(parentTxid: parentTxid));
    expect(components.vtxoId, vtxoId);
    expect(state.vtxoId, vtxoId);
    expect(state.phase, ArkSqlExitPhase.processing);
    expect(state.transactionRefs, isNotEmpty);
    final references = state.transactionRefs
        .where((r) => r.parentTxid == parentTxid)
        .toList();
    expect(references, hasLength(1));
    expect(references.single.phase.name, expected['transactionPhase']);
    expect(references.single.childTxid, expected['recordedChildTxid']);
    expect(child.parentTxid, parentTxid);
    expect(child.origin.name, expected['childOrigin']);
    expect(child.confirmedIn?.height, expected['confirmedHeight']);
    expect(child.confirmedIn?.hash, expected['confirmedHash']);
    final bare = components.rawBare;
    final genesis = components.rawGenesis;
    if (bare == null || genesis == null) {
      fail('Real board fixture must retain both components');
    }
    expect(bare, isNotEmpty);
    expect(genesis, isNotEmpty);
    expect(child.transactionBytes, isNotEmpty);
    bytesMatch(bare, expected['rawBare']);
    bytesMatch(genesis, expected['rawGenesis']);
    bytesMatch(child.transactionBytes, expected['childTransaction']);
    expect(() => bare[0] = 0, throwsUnsupportedError);
    expect(() => genesis[0] = 0, throwsUnsupportedError);
    expect(() => child.transactionBytes[0] = 0, throwsUnsupportedError);
    expect(() => state.transactionRefs.clear(), throwsUnsupportedError);
    // Each public read has completed and closed its connection. Retained DTOs
    // remain readable after removing our detached test file (not the fixture).
    detached.deleteSync();
    bytesMatch(bare, expected['rawBare']);
    bytesMatch(genesis, expected['rawGenesis']);
    bytesMatch(child.transactionBytes, expected['childTransaction']);
    // No inequality assertion: a VTXO's txid prefix may equal this parent.
    // No transaction decoding, Full assembly, signature or witness proof.
  });
}

T found<T>(Result<ArkSqlRead<T>, ArkWalletFailure> result) {
  expect(result, isA<Ok<ArkSqlRead<T>, ArkWalletFailure>>());
  final read = (result as Ok<ArkSqlRead<T>, ArkWalletFailure>).value;
  expect(read, isA<ArkSqlFound<T>>());
  return (read as ArkSqlFound<T>).value;
}

void bytesMatch(List<int> bytes, dynamic descriptor) {
  final expected = descriptor as Map<String, dynamic>;
  expect(expected['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
  expect(bytes.length, expected['byteLength']);
  expect(sha256.convert(bytes).toString(), expected['sha256']);
}
