import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';

import 'ark_funding_test_fixture.dart';

ArkFundingRequest requestOk(Result<ArkFundingRequest?, SyncFailure> result) =>
    switch (result) {
      Ok(value: final ArkFundingRequest value) => value,
      _ => throw StateError('Request prerequisite failed'),
    };

Future<void> requestRace((String, bool, SendPort) args) async {
  final (path, close, parent) = args;
  final control = ReceivePort();
  SqliteArkFundingReservations? cleanup;
  parent.send(['control', control.sendPort]);
  try {
    final store = sourceOk(
      SqliteArkFundingReservations.open(path, foreground: false),
    );
    cleanup = store;
    final request = requestOk(await store.readUnpreparedRequest('op'));
    parent.send(['ready']);
    if (await control.first != 'go') return;
    final result = close
        ? await store.closeNeverPrepared(
            expected: request,
            admittedRevision: fundingStamp,
          )
        : await store.reserve(
            key: fundingKey,
            spend: UnsignedSpend(
              revision: fundingStamp,
              encoded: publicFundingPsbt,
              inputs: decodeBitcoinPsbt(publicFundingPsbt).inputs,
              owner: SpendOwner(protocol: 'ark', session: 'op'),
            ),
            context: 'public-context',
          );
    parent.send(['done', result is Ok]);
  } on Exception catch (error) {
    parent.send(['failed', error.runtimeType.toString()]);
  } finally {
    cleanup?.close();
    control.close();
  }
}

void main() {
  late FundingFixture fixture;
  setUp(() => fixture = FundingFixture());
  tearDown(() => fixture.close());

  Future<ArkFundingRequest> begin() async {
    sourceOk(
      await fixture.store.beginBoardRequest(
        operationId: 'op',
        accountIdentity: 'public-account',
        sourceParent: Fingerprint('00112233'),
        key: fundingKey,
        generation: 1,
        context: 'public-context',
      ),
    );
    return requestOk(await fixture.store.readUnpreparedRequest('op'));
  }

  void sql(void Function(Database) action) {
    final db = sqlite3.open(fixture.path);
    try {
      action(db);
    } finally {
      db.close();
    }
  }

  Future<void> pinned(bool expected) async {
    switch (await fixture.store.getCustodyFingerprints()) {
      case Ok(:final value):
        expect(value.contains(Fingerprint('00112233')), expected);
      case Err():
        fail('Source references unavailable');
    }
  }

  test(
    'never-prepared request closes durably without erasing journal or any hold',
    () async {
      final request = await begin();
      expect(
        sourceOk(await fixture.store.pendingForAccount('public-account')),
        'op',
      );
      await pinned(true);
      sourceOk(
        await fixture.store.closeNeverPrepared(
          expected: request,
          admittedRevision: fundingStamp,
        ),
      );
      expect(
        sourceOk(await fixture.store.pendingForAccount('public-account')),
        isNull,
      );
      await pinned(false);
      expect(sourceOk(await fixture.store.reservations()), isEmpty);
      final reopened = sourceOk(
        SqliteArkFundingReservations.open(fixture.path, foreground: false),
      );
      try {
        expect(
          sourceOk(await reopened.pendingForAccount('public-account')),
          isNull,
        );
        sourceOk(await reopened.reservations());
      } finally {
        reopened.close();
      }
      sql((db) {
        final row = db.select('SELECT * FROM ark_funding_operations').single;
        expect(row['state'], 'tombstoned');
        expect(row['context'], request.context);
        expect(row['psbt'], isNull);
        final receipt = jsonDecode(
          db
                  .select('SELECT settlement FROM ark_funding_authority')
                  .single['settlement']
              as String,
        ) as Map<String, dynamic>;
        expect(receipt['kind'], 'neverPrepared');
        expect(receipt['signingBefore'], 'never_started');
        expect(receipt['version'], 1);
      });
      // A delayed original prepare can never reserve after the tombstone.
      expect(
        await fixture.store.reserve(
          key: fundingKey,
          spend: UnsignedSpend(
            revision: fundingStamp,
            encoded: publicFundingPsbt,
            inputs: decodeBitcoinPsbt(publicFundingPsbt).inputs,
            owner: SpendOwner(protocol: 'ark', session: 'op'),
          ),
          context: request.context,
        ),
        isA<Err>(),
      );
    },
  );

  for (final phase in ['reserved', 'signed']) {
    test('$phase is never eligible for request-only closure', () async {
      final request = await begin();
      final binding = await fixture.reserve('op');
      if (phase == 'signed') {
        sourceOk(
          await fixture.store.beginSigning(
            expected: binding,
            admittedRevision: fundingStamp,
          ),
        );
        final signed = structuralFinalWitness();
        expect(
          sourceOk(inspectBitcoinPsbt(signed)).finalTransaction,
          isNotNull,
        );
        sourceOk(await fixture.store.recordSigned('op', signed));
      }
      expect(sourceOk(await fixture.store.readUnpreparedRequest('op')), isNull);
      expect(
        await fixture.store.closeNeverPrepared(
          expected: request,
          admittedRevision: fundingStamp,
        ),
        isA<Err>(),
      );
      expect(sourceOk(await fixture.store.reservations()), hasLength(1));
      await pinned(true);
    });
  }

  for (final ambiguity in [
    'legacy',
    'unknown',
    'started',
    'revision',
    'psbt',
    'hold',
    'review',
  ]) {
    test(
      '$ambiguity request cannot turn missing bytes into a closure proof',
      () async {
        final request = await begin();
        sql((db) {
          switch (ambiguity) {
            case 'legacy':
              db.execute('DELETE FROM ark_funding_authority');
            case 'unknown':
              db.execute("UPDATE ark_funding_authority SET signing='unknown'");
            case 'started':
              db.execute("UPDATE ark_funding_authority SET signing='started'");
            case 'revision':
              db.execute('UPDATE ark_funding_operations SET revision=1');
            case 'psbt':
              db.execute('UPDATE ark_funding_operations SET psbt=?', [
                publicFundingPsbt,
              ]);
            case 'hold':
              db.execute('INSERT INTO ark_funding_inputs VALUES(?,?,?,?)', [
                'op',
                'regtest',
                '11' * 32,
                0,
              ]);
            case 'review':
              db.execute('INSERT INTO ark_board_reviews VALUES(?,?,?)', [
                'op',
                '{"public":true}',
                'prepared',
              ]);
          }
        });
        expect(await fixture.store.readUnpreparedRequest('op'), isA<Err>());
        expect(
          await fixture.store.closeNeverPrepared(
            expected: request,
            admittedRevision: fundingStamp,
          ),
          isA<Err>(),
        );
        sql((db) {
          expect(
            db
                .select('SELECT state FROM ark_funding_operations')
                .single['state'],
            'requested',
          );
          if (ambiguity == 'hold') {
            expect(db.select('SELECT * FROM ark_funding_inputs'), hasLength(1));
          }
        });
      },
    );
  }

  test(
    'exact request scope and native admission generation must match',
    () async {
      final request = await begin();
      final alternatives = <ArkFundingRequest>[
        (
          operationId: request.operationId,
          accountIdentity: 'other',
          sourceParent: request.sourceParent,
          key: request.key,
          generation: request.generation,
          context: request.context,
        ),
        (
          operationId: request.operationId,
          accountIdentity: request.accountIdentity,
          sourceParent: Fingerprint('ffeeddcc'),
          key: request.key,
          generation: request.generation,
          context: request.context,
        ),
        (
          operationId: request.operationId,
          accountIdentity: request.accountIdentity,
          sourceParent: request.sourceParent,
          key: WalletKey(id: 'alias', network: BitcoinNetwork.regtest),
          generation: request.generation,
          context: request.context,
        ),
        (
          operationId: request.operationId,
          accountIdentity: request.accountIdentity,
          sourceParent: request.sourceParent,
          key: request.key,
          generation: 2,
          context: request.context,
        ),
        (
          operationId: request.operationId,
          accountIdentity: request.accountIdentity,
          sourceParent: request.sourceParent,
          key: request.key,
          generation: request.generation,
          context: 'changed',
        ),
      ];
      for (final other in alternatives) {
        expect(
          await fixture.store.closeNeverPrepared(
            expected: other,
            admittedRevision: fundingStamp,
          ),
          isA<Err>(),
        );
      }
      expect(
        await fixture.store.closeNeverPrepared(
          expected: request,
          admittedRevision: WalletRevision(
            key: fundingKey,
            generation: 2,
            revision: 1,
          ),
        ),
        isA<Err>(),
      );
      expect(
        await fixture.store.closeNeverPrepared(
          expected: request,
          admittedRevision: WalletRevision(
            key: WalletKey(id: 'alias', network: BitcoinNetwork.regtest),
            generation: 1,
            revision: 1,
          ),
        ),
        isA<Err>(),
      );
      await pinned(true);
      expect(
        sourceOk(await fixture.store.pendingForAccount('public-account')),
        'op',
      );
    },
  );

  test(
    'unrelated reserved inputs survive request-only closure byte-for-byte',
    () async {
      final request = await begin();
      await fixture.reserve('protected', account: 'another-account');
      final before = sourceOk(await fixture.store.reservations());
      sourceOk(
        await fixture.store.closeNeverPrepared(
          expected: request,
          admittedRevision: fundingStamp,
        ),
      );
      final after = sourceOk(await fixture.store.reservations());
      expect(
        after.map((r) => (r.outpoint, r.session)),
        before.map((r) => (r.outpoint, r.session)),
      );
      await pinned(
        true,
      ); // The independent unresolved owner still needs this seed.
    },
  );

  for (final corruption in [
    'version',
    'request',
    'generation',
    'signingBefore',
  ]) {
    test(
      'corrupt $corruption neverPrepared receipt refuses after reopen',
      () async {
        final request = await begin();
        sourceOk(
          await fixture.store.closeNeverPrepared(
            expected: request,
            admittedRevision: fundingStamp,
          ),
        );
        sql((db) {
          final receipt = jsonDecode(
            db
                    .select('SELECT settlement FROM ark_funding_authority')
                    .single['settlement']
                as String,
          ) as Map<String, dynamic>;
          switch (corruption) {
            case 'version':
              receipt['version'] = 1.0;
            case 'request':
              (receipt['request'] as Map<String, dynamic>)['context'] =
                  'altered';
            case 'generation':
              (receipt['admitted'] as Map<String, dynamic>)['generation'] = 1.0;
            case 'signingBefore':
              receipt['signingBefore'] = 'unknown';
          }
          db.execute('UPDATE ark_funding_authority SET settlement=?', [
            jsonEncode(receipt),
          ]);
        });
        final reopened = sourceOk(
          SqliteArkFundingReservations.open(fixture.path, foreground: false),
        );
        try {
          expect(await reopened.reservations(), isA<Err>());
          expect(await reopened.getCustodyFingerprints(), isA<Err>());
        } finally {
          reopened.close();
        }
      },
    );
  }

  test('SQLite contention preserves the requested source pin', () async {
    final request = await begin();
    final lock = sqlite3.open(fixture.path);
    try {
      lock.execute('BEGIN IMMEDIATE');
      expect(
        await fixture.store.closeNeverPrepared(
          expected: request,
          admittedRevision: fundingStamp,
        ),
        isA<Err>(),
      );
      lock.execute('ROLLBACK');
    } finally {
      lock.close();
    }
    await pinned(true);
  });

  test(
    'independent reserve and neverPrepared CAS have exactly one winner',
    () async {
      await begin();
      final messages = ReceivePort();
      final stream = StreamIterator<dynamic>(messages);
      final exits = [ReceivePort(), ReceivePort()];
      final controls = <SendPort>[];
      final wins = <bool>[];
      for (var i = 0; i < 2; i++) {
        await Isolate.spawn(
          requestRace,
          (fixture.path, i == 0, messages.sendPort),
          onExit: exits[i].sendPort,
          onError: messages.sendPort,
        );
      }
      try {
        var ready = 0;
        while (controls.length < 2 || ready < 2) {
          expect(await stream.moveNext(), true);
          if (stream.current case ['control', final SendPort port]) {
            controls.add(port);
          } else if (stream.current case ['ready']) {
            ready++;
          } else {
            fail('Race prerequisite failed');
          }
        }
        for (final control in controls) {
          control.send('go');
        }
        while (wins.length < 2) {
          expect(await stream.moveNext(), true);
          if (stream.current case ['done', final bool success]) {
            wins.add(success);
          } else {
            fail('Race action failed before its result');
          }
        }
        expect(wins.where((win) => win), hasLength(1));
        final holds = sourceOk(await fixture.store.reservations());
        expect(holds.length, lessThanOrEqualTo(1));
        expect(
          sourceOk(await fixture.store.pendingForAccount('public-account')) ==
              null,
          holds.isEmpty,
        );
      } finally {
        for (final control in controls) {
          control.send('stop');
        }
        await Future.wait(exits.map((port) => port.first));
        for (final exit in exits) {
          exit.close();
        }
        await stream.cancel();
        messages.close();
      }
    },
  );
}
