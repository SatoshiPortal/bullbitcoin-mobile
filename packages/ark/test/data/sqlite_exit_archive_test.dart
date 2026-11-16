import 'dart:convert';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/src/data/exit_archive/ark_exit_archive.dart';
import 'package:ark/src/data/exit_archive/sqlite_exit_archive.dart';
import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

T value<T>(Result<T, ArkWalletFailure> result) {
  expect(result, isA<Ok<T, ArkWalletFailure>>());
  return (result as Ok<T, ArkWalletFailure>).value;
}

void main() {
  late Directory temp;
  late String path;
  late SqliteExitArchive archive;
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'archive-test',
  );
  final foreign = ArkAccountId(
    parent: Fingerprint('87654321'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'archive-test',
  );
  setUp(() {
    temp = Directory.systemTemp.createTempSync('ark-exit-archive-');
    path = '${temp.path}/archive.sqlite';
    archive = value(SqliteExitArchive.open(path, account, create: true));
  });
  tearDown(() async {
    await archive.close();
    temp.deleteSync(recursive: true);
  });
  Future<ArkExitCaptureIntent> begin({String? operation}) async => value(
    await archive.begin(
      ArkExitCaptureStage.payment,
      operationId: operation,
      sourceRevision: 7,
      knownInputs: ['input'],
    ),
  );
  Future<ArkExitArchiveView> read() async => value(await archive.read());
  Future<void> reopen() async {
    await archive.close();
    archive = value(SqliteExitArchive.open(path, account, create: false));
  }

  // These bytes exercise archive hashing/merging only; NOT valid native Full proofs.
  ArkExitProofVersion proof({
    String id = 'vtxo',
    String hex = '01',
    ArkExitWitnessState witnesses = ArkExitWitnessState.unknown,
    String? checkpoint,
    int encoding = 1,
  }) => ArkExitProofVersion(
    vtxoId: id,
    proofHash: sha256.convert([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]).toString(),
    fullHex: hex,
    encodingVersion: encoding,
    witnesses: witnesses,
    checkpointId: checkpoint,
  );
  ArkExitClaimMaterial material({
    int? index,
    bool verified = false,
    String? secret,
    String? hash,
    String? key,
  }) => ArkExitClaimMaterial(
    id: 'material',
    vtxoId: 'vtxo',
    keyIndex: index,
    indexVerified: verified,
    publicKey: key,
    preimage: secret,
    paymentHash: hash,
  );
  void sql(void Function(Database) action) {
    final db = sqlite3.open(path);
    try {
      action(db);
    } finally {
      db.close();
    }
  }

  test(
    'new archive binds identity and begins conservatively incomplete',
    () async {
      final first = await read();
      expect(first.identity.account, account);
      expect(first.identity.archiveId, hasLength(32));
      expect(first.state, ArkExitCaptureState.incomplete);
      expect(
        first.issues,
        contains(ArkExitCaptureIssue.nativeCoverageUnavailable),
      );
      expect(first.acknowledgedThrough, 0);
      final identity = first.identity;
      await reopen();
      expect((await read()).identity.matches(identity), isTrue);
      expect(() => first.proofs.clear(), throwsUnsupportedError);
    },
  );
  test('existing-only refuses missing file without creating it', () {
    final missing = '${temp.path}/missing.sqlite';
    expect(SqliteExitArchive.open(missing, account, create: false), isA<Err>());
    expect(File(missing).existsSync(), isFalse);
  });
  test(
    'foreign account, native pin and derivation profile refuse without reset',
    () async {
      final intent = await begin();
      for (final result in [
        SqliteExitArchive.open(path, foreign, create: true),
        SqliteExitArchive.open(
          path,
          account,
          create: true,
          nativeVersion: 'foreign',
        ),
        SqliteExitArchive.open(
          path,
          account,
          create: true,
          derivationProfile: 'foreign',
        ),
      ]) {
        expect(result, isA<Err>());
      }
      expect((await read()).pending.single.matches(intent), isTrue);
    },
  );
  test(
    'reconstructed durable intent commits and records survive restart',
    () async {
      final original = await begin(operation: 'payment');
      await reopen();
      final restored = (await read()).pending.single;
      expect(identical(original, restored), isFalse);
      expect(restored.matches(original), isTrue);
      final p = proof();
      value(
        await archive.commit(
          original,
          ArkExitCaptureBatch(
            proofs: [p],
            heads: [
              ArkExitProofHead(p.vtxoId, p.proofHash, ArkExitProofLife.active),
            ],
          ),
        ),
      );
      await reopen();
      final view = await read();
      expect(view.proofs.single.fullHex, p.fullHex);
      expect(view.heads.single.proofHash, p.proofHash);
      expect(view.pending.single.matches(original), isTrue);
      expect(view.state, ArkExitCaptureState.dirty);
    },
  );
  test(
    'altered and foreign durable records refuse commit and failed',
    () async {
      final i = await begin(operation: 'payment');
      final otherArchive = value(
        SqliteExitArchive.open('${temp.path}/other', account, create: true),
      );
      final otherId = value(await otherArchive.read()).identity;
      await otherArchive.close();
      final foreignIdentity = ArkExitArchiveIdentity(
        foreign,
        i.archive.nativeVersion,
        i.archive.derivationProfile,
        archiveId: i.archive.archiveId,
      );
      for (final altered in [
        ArkExitCaptureIntent(
          otherId,
          i.sequence,
          i.stage,
          operationId: i.operationId,
          sourceRevision: 7,
          knownInputs: ['input'],
        ),
        ArkExitCaptureIntent(
          foreignIdentity,
          i.sequence,
          i.stage,
          operationId: i.operationId,
          sourceRevision: 7,
          knownInputs: ['input'],
        ),
        ArkExitCaptureIntent(
          i.archive,
          i.sequence,
          i.stage,
          operationId: 'altered',
          sourceRevision: 7,
          knownInputs: ['input'],
        ),
        ArkExitCaptureIntent(
          i.archive,
          i.sequence,
          i.stage,
          operationId: i.operationId,
          sourceRevision: 8,
          knownInputs: ['input'],
        ),
        ArkExitCaptureIntent(
          i.archive,
          i.sequence,
          ArkExitCaptureStage.board,
          operationId: i.operationId,
          sourceRevision: 7,
          knownInputs: ['input'],
        ),
        ArkExitCaptureIntent(
          i.archive,
          i.sequence,
          i.stage,
          operationId: i.operationId,
          sourceRevision: 7,
          knownInputs: ['different'],
        ),
      ]) {
        expect(
          await archive.commit(altered, ArkExitCaptureBatch(proofs: [proof()])),
          isA<Err>(),
        );
        expect(await archive.failed(altered), isA<Err>());
      }
      final view = await read();
      expect(view.proofs, isEmpty);
      expect(view.issues, isNot(contains(ArkExitCaptureIssue.captureFailed)));
    },
  );
  test('failed capture keeps intent and never reuses its sequence', () async {
    final first = await begin();
    value(await archive.failed(first));
    await reopen();
    final second = await begin();
    expect(second.sequence, first.sequence + 1);
    final view = await read();
    expect(view.pending.map((i) => i.sequence), [1, 2]);
    expect(view.issues, contains(ArkExitCaptureIssue.captureFailed));
  });
  test(
    'byte-case equivalence, unknown refinement and provenance retention',
    () async {
      final i = await begin();
      final upper = proof(hex: 'AB', checkpoint: 'checkpoint');
      value(await archive.commit(i, ArkExitCaptureBatch(proofs: [upper])));
      value(
        await archive.commit(
          i,
          ArkExitCaptureBatch(
            proofs: [proof(hex: 'ab', witnesses: ArkExitWitnessState.complete)],
          ),
        ),
      );
      value(
        await archive.commit(
          i,
          ArkExitCaptureBatch(proofs: [proof(hex: 'AB')]),
        ),
      );
      await reopen();
      final p = (await read()).proofs.single;
      expect(p.fullHex, 'ab');
      expect(p.witnesses, ArkExitWitnessState.complete);
      expect(p.checkpointId, 'checkpoint');
      expect((await read()).state, ArkExitCaptureState.dirty);
    },
  );
  test('contradictory qualification and provenance cannot overwrite retained proof', () async {
    final i = await begin();
    value(
      await archive.commit(
        i,
        ArkExitCaptureBatch(
          proofs: [
            proof(witnesses: ArkExitWitnessState.missing, checkpoint: 'first'),
          ],
        ),
      ),
    );
    for (final p in [
      proof(witnesses: ArkExitWitnessState.complete),
      proof(checkpoint: 'different'),
    ]) {
      expect(
        await archive.commit(i, ArkExitCaptureBatch(proofs: [p])),
        isA<Err>(),
      );
    }
    expect((await read()).proofs.single.witnesses, ArkExitWitnessState.missing);
    expect((await read()).proofs.single.checkpointId, 'first');
  });
  test(
    'same hash with different bytes or encoding refuses atomically',
    () async {
      final i = await begin();
      final p = proof();
      for (final changed in [
        ArkExitProofVersion(
          vtxoId: p.vtxoId,
          proofHash: p.proofHash,
          fullHex: '02',
          encodingVersion: 1,
        ),
        proof(encoding: 2),
        ArkExitProofVersion(
          vtxoId: p.vtxoId,
          proofHash: p.proofHash,
          fullHex: 'not-hex',
          encodingVersion: 1,
        ),
      ]) {
        expect(
          await archive.commit(i, ArkExitCaptureBatch(proofs: [p, changed])),
          isA<Err>(),
        );
        expect((await read()).proofs, isEmpty);
      }
    },
  );
  test('enriched bytes retain old version and absence retains head', () async {
    final i = await begin();
    final old = proof(), enriched = proof(hex: '0102');
    value(
      await archive.commit(
        i,
        ArkExitCaptureBatch(
          proofs: [old],
          heads: [
            ArkExitProofHead('vtxo', old.proofHash, ArkExitProofLife.uncertain),
          ],
        ),
      ),
    );
    value(
      await archive.commit(
        i,
        ArkExitCaptureBatch(
          proofs: [enriched],
          heads: [
            ArkExitProofHead(
              'vtxo',
              enriched.proofHash,
              ArkExitProofLife.uncertain,
            ),
          ],
        ),
      ),
    );
    value(await archive.commit(i, ArkExitCaptureBatch(issues: {})));
    await reopen();
    expect((await read()).proofs.map((p) => p.proofHash).toSet(), {
      old.proofHash,
      enriched.proofHash,
    });
    expect((await read()).heads.single.proofHash, enriched.proofHash);
  });
  test(
    'head missing matching VTXO proof rolls back all earlier writes',
    () async {
      final i = await begin();
      final p = proof();
      expect(
        await archive.commit(
          i,
          ArkExitCaptureBatch(
            proofs: [p],
            heads: [
              ArkExitProofHead(
                'another-vtxo',
                p.proofHash,
                ArkExitProofLife.active,
              ),
            ],
          ),
        ),
        isA<Err>(),
      );
      expect((await read()).proofs, isEmpty);
    },
  );
  test(
    'arbitrary retirement strings never establish positive spending proof',
    () async {
      final i = await begin();
      final p = proof();
      value(
        await archive.commit(
          i,
          ArkExitCaptureBatch(
            proofs: [p],
            heads: [
              ArkExitProofHead('vtxo', p.proofHash, ArkExitProofLife.uncertain),
            ],
          ),
        ),
      );
      for (final life in [
        ArkExitProofLife.chainSpent,
        ArkExitProofLife.superseded,
      ]) {
        expect(
          await archive.commit(
            i,
            ArkExitCaptureBatch(
              heads: [
                ArkExitProofHead(
                  'vtxo',
                  p.proofHash,
                  life,
                  evidenceReference: 'asserted-positive',
                ),
              ],
            ),
          ),
          isA<Err>(),
        );
      }
      expect((await read()).heads.single.life, ArkExitProofLife.uncertain);
    },
  );
  test(
    'known secret and verified index survive partial material observations',
    () async {
      final i = await begin();
      final secret = '11' * 32, key = '02${'22' * 32}';
      final hash = sha256.convert(List.filled(32, 17)).toString();
      value(
        await archive.commit(
          i,
          ArkExitCaptureBatch(
            material: [
              material(
                index: 9000,
                verified: true,
                key: key,
                secret: secret,
                hash: hash,
              ),
            ],
          ),
        ),
      );
      value(
        await archive.commit(
          i,
          ArkExitCaptureBatch(material: [ArkExitClaimMaterial(id: 'material')]),
        ),
      );
      await reopen();
      final m = (await read()).material.single;
      expect(m.preimage, secret);
      expect(m.paymentHash, hash);
      expect(m.keyIndex, 9000);
      expect(m.indexVerified, isTrue);
      expect(m.publicKey, key);
      expect(m.toString(), isNot(contains(secret)));
    },
  );
  test(
    'material collision and preimage hash mismatch roll back whole batch',
    () async {
      final i = await begin();
      final key = '02${'22' * 32}';
      value(
        await archive.commit(
          i,
          ArkExitCaptureBatch(material: [material(key: key, index: 9)]),
        ),
      );
      for (final bad in [
        material(key: '03${'33' * 32}', index: 9),
        material(key: key, index: 10),
        material(secret: '11' * 32, hash: 'ff' * 32),
        material(verified: true),
      ]) {
        expect(
          await archive.commit(
            i,
            ArkExitCaptureBatch(proofs: [proof()], material: [bad]),
          ),
          isA<Err>(),
        );
        expect((await read()).proofs, isEmpty);
        expect((await read()).material.single.keyIndex, 9);
      }
    },
  );
  test(
    'two contradictory records in one batch cannot silently overwrite',
    () async {
      final i = await begin();
      expect(
        await archive.commit(
          i,
          ArkExitCaptureBatch(
            material: [
              material(key: '02${'22' * 32}', index: 1),
              material(key: '02${'22' * 32}', index: 2),
            ],
          ),
        ),
        isA<Err>(),
      );
      expect((await read()).material, isEmpty);
    },
  );
  test(
    'unknown material and witness cannot be acknowledged by empty issues',
    () async {
      final i = await begin();
      value(
        await archive.commit(
          i,
          ArkExitCaptureBatch(
            proofs: [proof()],
            material: [material()],
            issues: {ArkExitCaptureIssue.secretUnavailable},
          ),
        ),
      );
      value(await archive.commit(i, ArkExitCaptureBatch(issues: {})));
      for (final through in [-1, 0, 1, 2]) {
        expect(
          await archive.commit(
            i,
            ArkExitCaptureBatch(issues: {}, coveredThrough: through),
          ),
          isA<Err>(),
        );
      }
      await reopen();
      final view = await read();
      expect(view.acknowledgedThrough, 0);
      expect(view.pending, hasLength(1));
      expect(
        view.issues,
        containsAll([
          ArkExitCaptureIssue.nativeCoverageUnavailable,
          ArkExitCaptureIssue.secretUnavailable,
        ]),
      );
      expect(view.state, ArkExitCaptureState.dirty);
    },
  );
  test(
    'latest partial catch-up never closes earlier unresolved intents',
    () async {
      final first = await begin();
      value(await archive.failed(first));
      final second = value(await archive.begin(ArkExitCaptureStage.catchUp));
      expect(
        await archive.commit(
          second,
          ArkExitCaptureBatch(issues: {}, coveredThrough: second.sequence),
        ),
        isA<Err>(),
      );
      value(await archive.commit(second, ArkExitCaptureBatch(issues: {})));
      await reopen();
      expect((await read()).pending.map((i) => i.sequence), [1, 2]);
      expect((await read()).acknowledgedThrough, 0);
    },
  );
  test(
    'last logical write failure rolls back every table and survives restart',
    () async {
      final i = await begin();
      final old = proof();
      value(
        await archive.commit(
          i,
          ArkExitCaptureBatch(
            proofs: [old],
            heads: [
              ArkExitProofHead('vtxo', old.proofHash, ArkExitProofLife.active),
            ],
          ),
        ),
      );
      sql(
        (db) => db.execute(
          "CREATE TRIGGER abort_archive_meta BEFORE UPDATE ON archive_meta BEGIN SELECT RAISE(ABORT,'injected'); END",
        ),
      );
      final fresh = proof(hex: '02');
      expect(
        await archive.commit(
          i,
          ArkExitCaptureBatch(
            proofs: [fresh],
            heads: [
              ArkExitProofHead(
                'vtxo',
                fresh.proofHash,
                ArkExitProofLife.pending,
              ),
            ],
            material: [material()],
            issues: {ArkExitCaptureIssue.captureFailed},
          ),
        ),
        isA<Err>(),
      );
      await reopen();
      final view = await read();
      expect(view.proofs.single.proofHash, old.proofHash);
      expect(view.heads.single.proofHash, old.proofHash);
      expect(view.material, isEmpty);
      expect(view.pending.single.matches(i), isTrue);
      expect(view.issues, isNot(contains(ArkExitCaptureIssue.captureFailed)));
    },
  );
  test('close drains already admitted synchronous SQL and every later method refuses', () async {
    final i = await begin();
    final admitted = archive.commit(i, ArkExitCaptureBatch(proofs: [proof()]));
    await archive.close();
    value(await admitted);
    expect(await archive.read(), isA<Err>());
    expect(await archive.begin(ArkExitCaptureStage.open), isA<Err>());
    expect(await archive.failed(i), isA<Err>());
    expect(await archive.commit(i, ArkExitCaptureBatch()), isA<Err>());
    await reopen();
    expect((await read()).proofs, hasLength(1));
  });
  for (final mutation in [
    'version',
    'table',
    'payload',
    'sequence',
    'missing-intent',
    'intent-archive',
  ]) {
    test(
      'initialized $mutation corruption refuses open without reset',
      () async {
        await begin();
        await archive.close();
        sql((db) {
          switch (mutation) {
            case 'version':
              db.execute('PRAGMA user_version=2');
            case 'table':
              db.execute('DROP TABLE claim_material');
            case 'payload':
              db.execute("UPDATE archive_meta SET value='not-json'");
            case 'sequence':
              final m = jsonDecode(
                db.select('SELECT value FROM archive_meta').single['value']
                    as String,
              ) as Map<String, dynamic>;
              m['sequence'] = 2;
              db.execute('UPDATE archive_meta SET value=?', [jsonEncode(m)]);
            case 'intent-archive':
              final record = jsonDecode(
                db.select('SELECT value FROM capture_intents').single['value']
                    as String,
              ) as Map<String, dynamic>;
              record['archive'] = 'foreign-archive';
              db.execute('UPDATE capture_intents SET value=?', [
                jsonEncode(record),
              ]);
            case 'missing-intent':
              db.execute('DELETE FROM capture_intents');
          }
        });
        final reopened = SqliteExitArchive.open(path, account, create: true);
        if (reopened case Ok(:final value)) {
          await value.close();
        }
        expect(reopened, isA<Err>());
        final db = sqlite3.open(path);
        try {
          expect(
            db.select('SELECT count(*) AS n FROM capture_intents').single['n'],
            mutation == 'missing-intent' ? 0 : 1,
          );
        } finally {
          db.close();
        }
      },
    );
  }
  String dump() {
    var result = '';
    sql((db) {
      result = jsonEncode([
        for (final table in [
          'archive_meta',
          'proof_versions',
          'vtxo_heads',
          'claim_material',
          'capture_intents',
        ])
          [
            table,
            for (final row in db.select(
              'SELECT id,value FROM $table ORDER BY id',
            ))
              row.values.toList(),
          ],
      ]);
    });
    return result;
  }

  void mutatePayload(String table, void Function(Map<String, dynamic>) change) {
    sql((db) {
      final row = db.select('SELECT id,value FROM $table ORDER BY id').first;
      final decoded =
          jsonDecode(row['value'] as String) as Map<String, dynamic>;
      change(decoded);
      db.execute('UPDATE $table SET value=? WHERE id=?', [
        jsonEncode(decoded),
        row['id'],
      ]);
    });
  }

  Future<void> refuseReadAndOpenWithoutRepair() async {
    final unchanged = dump();
    expect(await archive.read(), isA<Err>());
    await archive.close();
    final result = SqliteExitArchive.open(path, account, create: true);
    if (result case Ok(:final value)) {
      await value.close();
    }
    expect(result, isA<Err>());
    expect(dump(), unchanged);
  }

  test(
    'duplicate in-range payload sequence cannot hide another durable intent',
    () async {
      await begin(operation: 'first');
      await begin(operation: 'second');
      sql(
        (db) => db.execute(
          "UPDATE capture_intents SET value=(SELECT value FROM capture_intents WHERE id='1') WHERE id='2'",
        ),
      );
      await refuseReadAndOpenWithoutRepair();
    },
  );
  for (final table in [
    'archive_meta',
    'proof_versions',
    'vtxo_heads',
    'claim_material',
    'capture_intents',
  ]) {
    test(
      'SQL key mismatch in $table refuses without repairing retained evidence',
      () async {
        final i = await begin();
        final p = proof();
        value(
          await archive.commit(
            i,
            ArkExitCaptureBatch(
              proofs: [p],
              heads: [
                ArkExitProofHead(
                  p.vtxoId,
                  p.proofHash,
                  ArkExitProofLife.active,
                ),
              ],
              material: [material()],
            ),
          ),
        );
        sql((db) => db.execute("UPDATE $table SET id='renamed-key'"));
        await refuseReadAndOpenWithoutRepair();
      },
    );
  }
  for (final field in [
    'negative-revision',
    'duplicate-inputs',
    'empty-input',
    'terminal-head',
  ]) {
    test('stored $field is rejected as strictly as incoming records', () async {
      final i = await begin();
      final p = proof();
      value(
        await archive.commit(
          i,
          ArkExitCaptureBatch(
            proofs: [p],
            heads: [
              ArkExitProofHead(p.vtxoId, p.proofHash, ArkExitProofLife.active),
            ],
          ),
        ),
      );
      if (field == 'terminal-head') {
        mutatePayload(
          'vtxo_heads',
          (m) => m['life'] = ArkExitProofLife.chainSpent.name,
        );
      } else {
        mutatePayload('capture_intents', (m) {
          switch (field) {
            case 'negative-revision':
              m['revision'] = -1;
            case 'duplicate-inputs':
              m['inputs'] = ['input', 'input'];
            case 'empty-input':
              m['inputs'] = [''];
          }
        });
      }
      await refuseReadAndOpenWithoutRepair();
    });
  }
  for (final corruption in [
    'identity',
    'extra-meta',
    'ack',
    'version',
    'row',
  ]) {
    test(
      'post-open $corruption corruption blocks every write without side effects',
      () async {
        final i = await begin();
        final p = proof();
        value(
          await archive.commit(
            i,
            ArkExitCaptureBatch(
              proofs: [p],
              heads: [
                ArkExitProofHead(
                  p.vtxoId,
                  p.proofHash,
                  ArkExitProofLife.active,
                ),
              ],
            ),
          ),
        );
        switch (corruption) {
          case 'identity':
            mutatePayload(
              'archive_meta',
              (m) => m['account'] = foreign.canonical,
            );
          case 'extra-meta':
            sql(
              (db) => db.execute(
                "INSERT INTO archive_meta SELECT 'extra',value FROM archive_meta WHERE id='state'",
              ),
            );
          case 'ack':
            mutatePayload('archive_meta', (m) => m['ack'] = 1);
          case 'version':
            sql((db) => db.execute('PRAGMA user_version=2'));
          case 'row':
            mutatePayload(
              'vtxo_heads',
              (m) => m['life'] = ArkExitProofLife.superseded.name,
            );
        }
        final unchanged = dump();
        expect(await archive.begin(ArkExitCaptureStage.board), isA<Err>());
        expect(dump(), unchanged);
        expect(
          await archive.commit(
            i,
            ArkExitCaptureBatch(proofs: [proof(hex: '02')]),
          ),
          isA<Err>(),
        );
        expect(dump(), unchanged);
        expect(await archive.failed(i), isA<Err>());
        expect(dump(), unchanged);
      },
    );
  }
}
