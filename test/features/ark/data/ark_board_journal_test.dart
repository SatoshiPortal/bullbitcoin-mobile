import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';

import 'ark_funding_test_fixture.dart';

void main() {
  late FundingFixture fixture;
  setUp(() => fixture = FundingFixture());
  tearDown(() => fixture.close());

  test(
    'a second Board request cannot orphan the first uncertain account pin',
    () async {
      sourceOk(
        await fixture.store.beginBoardRequest(
          operationId: 'original',
          accountIdentity: 'account',
          sourceParent: Fingerprint('00112233'),
          key: fundingKey,
          generation: 1,
          context: 'public',
        ),
      );
      expect(
        await fixture.store.beginBoardRequest(
          operationId: 'second',
          accountIdentity: 'account',
          sourceParent: Fingerprint('00112233'),
          key: fundingKey,
          generation: 1,
          context: 'public',
        ),
        isA<Err>(),
      );
      expect(
        sourceOk(await fixture.store.pendingForAccount('account')),
        'original',
      );
      final db = sqlite3.open(fixture.path);
      try {
        expect(
          db.select('SELECT operation FROM ark_funding_operations'),
          hasLength(1),
        );
      } finally {
        db.close();
      }
    },
  );
  test(
    'review is immutable and a second engine cannot acquire the same signer',
    () async {
      final binding = await fixture.reserve('op');
      sourceOk(await fixture.store.saveBoardReview('op', '{"public":true}'));
      sourceOk(await fixture.store.saveBoardReview('op', '{"public":true}'));
      expect(
        await fixture.store.saveBoardReview('op', '{"changed":true}'),
        isA<Err>(),
      );
      final second = sourceOk(
        SqliteArkFundingReservations.open(fixture.path, foreground: false),
      );
      try {
        final results = await Future.wait([
          fixture.store.admitBoardSigning(
            expected: binding,
            admittedRevision: fundingStamp,
          ),
          second.admitBoardSigning(
            expected: binding,
            admittedRevision: fundingStamp,
          ),
        ]);
        expect(results.whereType<Ok>(), hasLength(1));
        expect(results.whereType<Err>(), hasLength(1));
        final entry = sourceOk(await second.readBoardReview('op'));
        expect(entry.phase, 'signing');
        expect(entry.signedPsbt, isNull); // Absence never rearms signing.
        expect(
          await second.tombstoneNeverSigned(
            expected: binding,
            admittedRevision: fundingStamp,
          ),
          isA<Err>(),
        );
      } finally {
        second.close();
      }
    },
  );
  test('delivery phases survive reopen and never permit rebroadcast admission twice', () async {
    final binding = await fixture.reserve('op');
    sourceOk(await fixture.store.saveBoardReview('op', '{"public":true}'));
    sourceOk(
      await fixture.store.admitBoardSigning(
        expected: binding,
        admittedRevision: fundingStamp,
      ),
    );
    final signed = structuralFinalWitness();
    final facts = sourceOk(inspectBitcoinPsbt(signed));
    expect(facts.finalTransaction, isNotNull);
    expect(facts.unsignedTxid, binding.unsignedTxid);
    sourceOk(await fixture.store.recordSigned('op', signed));
    sourceOk(
      await fixture.store.advanceBoardDelivery(
        'op',
        expectedPhase: 'signing',
        nextPhase: 'signed',
      ),
    );
    sourceOk(
      await fixture.store.advanceBoardDelivery(
        'op',
        expectedPhase: 'signed',
        nextPhase: 'broadcasting',
      ),
    );
    final reopened = sourceOk(
      SqliteArkFundingReservations.open(fixture.path, foreground: false),
    );
    try {
      expect(
        sourceOk(await reopened.readBoardReview('op')).phase,
        'broadcasting',
      );
      expect(
        await reopened.advanceBoardDelivery(
          'op',
          expectedPhase: 'signed',
          nextPhase: 'broadcasting',
        ),
        isA<Err>(),
      );
      expect(
        await reopened.admitBoardSigning(
          expected: binding,
          admittedRevision: fundingStamp,
        ),
        isA<Err>(),
      );
      sourceOk(
        await reopened.finishBoardBroadcast(
          'op',
          SpendReceipt(binding.unsignedTxid, durable: true, guarded: true),
        ),
      );
      expect(sourceOk(await reopened.readBoardReview('op')).phase, 'broadcast');
    } finally {
      reopened.close();
    }
  });
  test(
    'without a sealed signed journal, a phase label cannot authorize delivery',
    () async {
      await fixture.reserve('op');
      sourceOk(await fixture.store.saveBoardReview('op', '{"public":true}'));
      expect(
        await fixture.store.advanceBoardDelivery(
          'op',
          expectedPhase: 'prepared',
          nextPhase: 'broadcasting',
        ),
        isA<Err>(),
      );
      final db = sqlite3.open(fixture.path);
      try {
        db.execute("UPDATE ark_board_reviews SET phase='signed'");
      } finally {
        db.close();
      }
      expect(
        await fixture.store.advanceBoardDelivery(
          'op',
          expectedPhase: 'signed',
          nextPhase: 'broadcasting',
        ),
        isA<Err>(),
      );
    },
  );
  test(
    'failed durable review publication preserves the original reserved inputs',
    () async {
      await fixture.reserve('op');
      final lock = sqlite3.open(fixture.path);
      try {
        lock.execute('BEGIN IMMEDIATE');
        expect(
          await fixture.store.saveBoardReview('op', '{"public":true}'),
          isA<Err>(),
        );
        lock.execute('ROLLBACK');
        expect(sourceOk(await fixture.store.reservations()), hasLength(1));
        expect(await fixture.store.readBoardReview('op'), isA<Err>());
      } finally {
        lock.close();
      }
    },
  );
  test('orphan review inventory cannot become an unrelated negative classification', () async {
    final db = sqlite3.open(fixture.path);
    try {
      db.execute('PRAGMA foreign_keys=OFF');
      db.execute(
        "INSERT INTO ark_board_reviews VALUES('missing','public','prepared')",
      );
    } finally {
      db.close();
    }
    expect(
      await fixture.store.bindingForSigning(
        key: fundingKey,
        unsignedPsbt: publicFundingPsbt,
      ),
      isA<Err>(),
    );
  });
}
