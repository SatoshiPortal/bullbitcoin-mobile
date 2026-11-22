import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:primitives/primitives.dart';
import 'package:swaps/src/payment/domain/payment.dart';
import 'package:swaps/src/payment/data/payment_database.dart';
import 'package:swaps/src/payment/domain/payment_ledger.dart';
import 'package:test/test.dart';
import 'package:swaps/src/payment/domain/payment_ledger_failure.dart';
import 'package:swaps/src/payment/data/drift_payment_ledger.dart';

void main() {
  late Directory directory;
  late File file;
  late PaymentDatabase db1;
  late PaymentDatabase db2;
  late PaymentLedger first;
  late PaymentLedger second;
  final liquid = PaymentSource('liquid-wallet', 'liquid', 1200);
  final bitcoin = PaymentSource('bitcoin-wallet', 'bitcoin', 1500);
  final review = PaymentReview('settings-revision-7', [liquid, bitcoin]);
  PaymentKey key([NetworkEnv network = NetworkEnv.testnet]) =>
      PaymentKey(network, 'a' * 64);
  BoundPaymentRequest request([NetworkEnv network = NetworkEnv.testnet]) =>
      BoundPaymentRequest(key(network), 'bound-invoice', 1000001);
  PaymentDatabase open() => PaymentDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (database) {
        database.execute('PRAGMA busy_timeout = 5000');
        database.execute('PRAGMA journal_mode = WAL');
      },
    ),
  );
  Future<void> reopen() async {
    await db1.close();
    await db2.close();
    db1 = open();
    db2 = open();
    first = DriftPaymentLedger(db1);
    second = DriftPaymentLedger(db2);
  }

  Future<T> ok<T>(Future<Result<T, PaymentLedgerFailure>> pending) async =>
      switch (await pending) {
        Ok(:final value) => value,
        Err(:final failure) => fail('Unexpected ledger failure: $failure'),
      };

  PaymentAttempt active(PaymentSnapshot payment) {
    final attempt = payment.active;
    if (attempt == null) fail('Expected active attempt');
    return attempt;
  }

  String backend(PaymentSnapshot payment) {
    final reference = active(payment).backendReference;
    if (reference == null) fail('Expected backend reference');
    return reference;
  }

  Future<PaymentSnapshot> required(PaymentLedger ledger, PaymentKey key) async {
    final payment = await ok(ledger.read(key));
    if (payment == null) fail('Expected persisted payment');
    return payment;
  }

  Matcher failure(PaymentLedgerFailure kind) => completion(
    isA<Err<Object?, PaymentLedgerFailure>>().having(
      (result) => result.failure,
      'failure',
      kind,
    ),
  );

  Future<void> expectOneWinner(
    Future<Result<PaymentSnapshot, PaymentLedgerFailure>> Function() first,
    Future<Result<PaymentSnapshot, PaymentLedgerFailure>> Function() second,
  ) async {
    final commands = [first, second];
    final results = await Future.wait(commands.map((command) => command()));
    expect(
      results.whereType<Ok<PaymentSnapshot, PaymentLedgerFailure>>(),
      hasLength(1),
    );
    for (final (index, result) in results.indexed) {
      if (result case Err(failure: final rejection)) {
        if (rejection == PaymentLedgerFailure.busy) {
          // Once the winner has committed, the losing revision is stale.
          await expectLater(
            commands[index](),
            failure(PaymentLedgerFailure.stale),
          );
        } else {
          expect(rejection, PaymentLedgerFailure.stale);
        }
      }
    }
  }

  PreflightRefusal refusal(PaymentSnapshot p) => PreflightRefusal(
    network: p.request.key.network,
    operationId: active(p).operationId,
    walletId: active(p).source.walletId,
    reason: PreflightRefusalReason.insufficientFunds,
    reference: 'authoritative-preflight',
  );
  PaymentReceipt receipt(
    PaymentSnapshot p, [
    String reference = 'source-receipt',
  ]) => PaymentReceipt(
    network: p.request.key.network,
    operationId: active(p).operationId,
    walletId: active(p).source.walletId,
    backendReference: backend(p),
    reference: reference,
  );
  Future<PaymentSnapshot> preflight() async {
    final p = await ok(first.createOrReadReview(request(), review));
    return ok(
      first.beginPreflight(key(), p.revision, liquid, 'operation-liquid'),
    );
  }

  Future<PaymentSnapshot> funded() async {
    var p = await preflight();
    p = await ok(first.sealCreate(p, active(p)));
    p = await ok(first.linkCreated(p, active(p), 'boltz-id'));
    return ok(first.sealFunding(p, active(p)));
  }

  test('bound identities and exact amount ranges reject invalid input', () {
    expect(
      () => PaymentKey(NetworkEnv.testnet, 'A' * 64),
      throwsFormatException,
    );
    expect(
      () => BoundPaymentRequest(key(), 'invoice', 0),
      throwsFormatException,
    );
    expect(
      () => BoundPaymentRequest(key(), 'invoice', 2100000000000000001),
      throwsFormatException,
    );
    expect(() => PaymentReview('empty', []), throwsFormatException);
    expect(() => PaymentSource('wallet', 'ark', 1), throwsFormatException);
  });

  // Every connection has its own background executor; concurrent instances are intentional.
  final previousWarningSetting =
      driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(
    () => driftRuntimeOptions.dontWarnAboutMultipleDatabases =
        previousWarningSetting,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('payment-ledger-');
    file = File('${directory.path}/ledger.sqlite');
    db1 = open();
    db2 = open();
    first = DriftPaymentLedger(db1);
    second = DriftPaymentLedger(db2);
    // Schema creation is foreground-only; initialize before the second opens.
    await ok(first.read(key()));
    await ok(second.read(key()));
  });
  tearDown(() async {
    await db1.close();
    await db2.close();
    await directory.delete(recursive: true);
  });

  test(
    'independent connections converge by hash and preserve exact millisatoshis',
    () async {
      final results = await Future.wait([
        ok(first.createOrReadReview(request(), review)),
        ok(second.createOrReadReview(request(), review)),
      ]);
      expect(results.map((p) => p.revision), everyElement(1));
      expect(results.first.request.amountMsat, 1000001);
      await expectLater(
        first.createOrReadReview(
          BoundPaymentRequest(key(), 'bound-invoice', 1000000),
          review,
        ),
        failure(PaymentLedgerFailure.conflict),
      );
      await expectLater(
        first.createOrReadReview(
          BoundPaymentRequest(key(), 'other-invoice', 1000001),
          review,
        ),
        failure(PaymentLedgerFailure.conflict),
      );
      expect(
        (await ok(
          first.createOrReadReview(request(NetworkEnv.regtest), review),
        )).revision,
        1,
      );
      expect(
        (await db1
                .customSelect('SELECT COUNT(*) AS n FROM payments')
                .getSingle())
            .read<int>('n'),
        2,
      );
    },
  );

  test('snapshot owns an immutable copy of its attempts', () async {
    final p = await preflight();
    final input = p.attempts.toList();
    final copy = PaymentSnapshot(
      request: p.request,
      review: p.review,
      reviewId: p.reviewId,
      revision: p.revision,
      attemptCount: p.attemptCount,
      stage: p.stage,
      attempts: input,
      activeOrdinal: p.activeOrdinal,
    );
    input.clear();
    expect(copy.attempts, hasLength(1));
    expect(() => copy.attempts.clear(), throwsUnsupportedError);
  });

  test('active tombstone pointer is corruption', () async {
    var p = await preflight();
    p = await ok(first.closePreflightRefused(p, active(p), refusal(p)));
    await db1.customStatement(
      "UPDATE payments SET active_ordinal = 1, stage = 'preflightRefused'",
    );
    await expectLater(
      second.read(key()),
      failure(PaymentLedgerFailure.recoveryRequired),
    );
  });

  test('backend linkage before creating is corruption', () async {
    await preflight();
    await db1.customStatement(
      "UPDATE payment_attempts SET backend = 'unexpected-contract'",
    );
    await expectLater(
      second.read(key()),
      failure(PaymentLedgerFailure.recoveryRequired),
    );
  });

  test(
    'corrupt creating linkage cannot be hidden by a late create reply',
    () async {
      var p = await preflight();
      p = await ok(first.sealCreate(p, active(p)));
      await db1.customStatement(
        "UPDATE payment_attempts SET backend = 'unexpected-contract'",
      );
      await expectLater(
        first.linkCreated(p, active(p), 'unexpected-contract'),
        failure(PaymentLedgerFailure.recoveryRequired),
      );
      expect(
        (await db1.customSelect('SELECT revision FROM payments').getSingle())
            .read<int>('revision'),
        p.revision,
      );
      expect(
        (await db1
                .customSelect('SELECT stage FROM payment_attempts')
                .getSingle())
            .read<String>('stage'),
        'creating',
      );
    },
  );

  test('future schema is recovery-required and remains untouched', () async {
    await ok(first.createOrReadReview(request(), review));
    await db1.customStatement('PRAGMA user_version = 2');
    await db1.close();
    db1 = open();
    first = DriftPaymentLedger(db1);
    await expectLater(
      first.read(key()),
      failure(PaymentLedgerFailure.recoveryRequired),
    );
    expect(
      (await db2.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      2,
    );
    expect(
      (await db2.customSelect('SELECT COUNT(*) AS n FROM payments').getSingle())
          .read<int>('n'),
      1,
    );
  });

  test('corrupt current review cannot be replaced or hidden', () async {
    final p = await ok(first.createOrReadReview(request(), review));
    await db1.customStatement(
      "UPDATE payment_reviews SET sources = 'bad-json'",
    );
    await expectLater(
      first.replaceUnadmittedReview(
        key(),
        p.revision,
        PaymentReview('replacement', [bitcoin]),
      ),
      failure(PaymentLedgerFailure.recoveryRequired),
    );
    final stored = await db1
        .customSelect(
          'SELECT revision, review_id, active_ordinal FROM payments',
        )
        .getSingle();
    expect(stored.read<int>('revision'), p.revision);
    expect(stored.read<int>('review_id'), p.reviewId);
    expect(stored.readNullable<int>('active_ordinal'), isNull);
    expect(
      (await db1
              .customSelect('SELECT COUNT(*) AS n FROM payment_reviews')
              .getSingle())
          .read<int>('n'),
      1,
    );
  });

  test(
    'review replacement appends immutable history only before any admission',
    () async {
      var p = await ok(first.createOrReadReview(request(), review));
      p = await ok(
        first.replaceUnadmittedReview(
          key(),
          p.revision,
          PaymentReview('forced', [bitcoin]),
        ),
      );
      expect(p.reviewId, 2);
      expect(
        (await db1
                .customSelect('SELECT COUNT(*) AS n FROM payment_reviews')
                .getSingle())
            .read<int>('n'),
        2,
      );
      await expectLater(
        first.beginPreflight(key(), p.revision, liquid, 'wrong-source'),
        failure(PaymentLedgerFailure.conflict),
      );
      expect((await required(first, key())).revision, p.revision);
      p = await ok(
        first.beginPreflight(key(), p.revision, bitcoin, 'forced-operation'),
      );
      p = await ok(first.closePreflightRefused(p, active(p), refusal(p)));
      await expectLater(
        first.replaceUnadmittedReview(key(), p.revision, review),
        failure(PaymentLedgerFailure.stale),
      );
      await expectLater(
        first.beginPreflight(key(), p.revision, liquid, 'escape'),
        failure(PaymentLedgerFailure.conflict),
      );
    },
  );

  test(
    'two real connections admit exactly one attempt at one revision',
    () async {
      final p = await ok(first.createOrReadReview(request(), review));
      await expectOneWinner(
        () => first.beginPreflight(key(), p.revision, liquid, 'one'),
        () => second.beginPreflight(key(), p.revision, liquid, 'two'),
      );
      final stored = (await required(second, key()));
      expect(stored.attempts, hasLength(1));
      expect(stored.revision, 2);
      expect(stored.activeOrdinal, 1);
    },
  );

  test(
    'preflight refusal and create seal compete on the same predecessor',
    () async {
      final p = await preflight();
      await expectOneWinner(
        () => first.closePreflightRefused(p, active(p), refusal(p)),
        () => second.sealCreate(p, active(p)),
      );
      final stored = (await required(first, key()));
      expect(stored.revision, 3);
      if (stored.active == null) {
        expect(stored.attempts.single.stage, PaymentStage.preflightRefused);
        final next = await ok(
          second.beginPreflight(
            key(),
            stored.revision,
            bitcoin,
            'bitcoin-operation',
          ),
        );
        expect(next.attempts, hasLength(2));
      } else {
        expect(stored.stage, PaymentStage.creating);
        await expectLater(
          first.beginPreflight(key(), stored.revision, bitcoin, 'forbidden'),
          failure(PaymentLedgerFailure.stale),
        );
      }
    },
  );

  test('positive preflight refusal persists and permits only the next captured source once', () async {
    var p = await preflight();
    p = await ok(first.closePreflightRefused(p, active(p), refusal(p)));
    await reopen();
    p = (await required(first, key()));
    expect(
      p.attempts.single.receiptReference,
      contains('authoritative-preflight'),
    );
    await expectLater(
      first.beginPreflight(key(), p.revision, liquid, 'repeat-liquid'),
      failure(PaymentLedgerFailure.conflict),
    );
    p = await ok(
      first.beginPreflight(key(), p.revision, bitcoin, 'bitcoin-operation'),
    );
    expect(active(p).source.walletId, bitcoin.walletId);
    await expectLater(
      second.beginPreflight(key(), p.revision, bitcoin, 'repeat-bitcoin'),
      failure(PaymentLedgerFailure.stale),
    );
    p = await ok(first.closePreflightRefused(p, active(p), refusal(p)));
    await expectLater(
      first.beginPreflight(key(), p.revision, bitcoin, 'exhausted'),
      failure(PaymentLedgerFailure.conflict),
    );
    expect((await required(first, key())).attemptCount, 2);
  });

  test(
    'duplicate operation id rolls back a different payment admission',
    () async {
      await preflight();
      final otherKey = PaymentKey(NetworkEnv.testnet, 'b' * 64);
      final other = await ok(
        second.createOrReadReview(
          BoundPaymentRequest(otherKey, 'other-invoice', 1000001),
          review,
        ),
      );
      await expectLater(
        second.beginPreflight(
          otherKey,
          other.revision,
          liquid,
          'operation-liquid',
        ),
        failure(PaymentLedgerFailure.conflict),
      );
      final stored = (await required(first, otherKey));
      expect(stored.revision, 1);
      expect(stored.attemptCount, 0);
      expect(stored.activeOrdinal, isNull);
    },
  );

  test('attempt update failure rolls back the preceding payment CAS', () async {
    final p = await preflight();
    final wrong = PaymentAttempt(
      ordinal: active(p).ordinal,
      operationId: 'wrong-operation',
      reviewId: p.reviewId,
      source: liquid,
      stage: PaymentStage.preflight,
    );
    await expectLater(
      first.sealCreate(p, wrong),
      failure(PaymentLedgerFailure.stale),
    );
    final stored = (await required(second, key()));
    expect(stored.revision, p.revision);
    expect(stored.stage, PaymentStage.preflight);
    expect(active(stored).operationId, 'operation-liquid');
  });

  test('restart at every seal retains the same blocked attempt', () async {
    var p = await preflight();
    await reopen();
    p = (await required(first, key()));
    expect(p.stage, PaymentStage.preflight);
    p = await ok(first.sealCreate(p, active(p)));
    await reopen();
    p = (await required(first, key()));
    expect(p.stage, PaymentStage.creating);
    await expectLater(
      first.closePreflightRefused(p, active(p), refusal(p)),
      failure(PaymentLedgerFailure.stale),
    );
    await expectLater(
      first.beginPreflight(
        key(),
        p.revision,
        bitcoin,
        'blocked-${p.stage.name}',
      ),
      failure(PaymentLedgerFailure.stale),
    );
    await expectLater(
      first.closePreflightRefused(p, active(p), refusal(p)),
      failure(PaymentLedgerFailure.stale),
    );
    p = await ok(first.linkCreated(p, active(p), 'boltz-id'));
    await reopen();
    p = (await required(first, key()));
    expect(p.stage, PaymentStage.created);
    await expectLater(
      first.closePreflightRefused(p, active(p), refusal(p)),
      failure(PaymentLedgerFailure.stale),
    );
    await expectLater(
      first.beginPreflight(
        key(),
        p.revision,
        bitcoin,
        'blocked-${p.stage.name}',
      ),
      failure(PaymentLedgerFailure.stale),
    );
    p = await ok(first.sealFunding(p, active(p)));
    await reopen();
    p = (await required(first, key()));
    expect(p.stage, PaymentStage.fundingSealed);
    await expectLater(
      first.closePreflightRefused(p, active(p), refusal(p)),
      failure(PaymentLedgerFailure.stale),
    );
    await expectLater(
      first.beginPreflight(
        key(),
        p.revision,
        bitcoin,
        'blocked-${p.stage.name}',
      ),
      failure(PaymentLedgerFailure.stale),
    );
    p = await ok(first.recordPending(p, active(p), receipt(p)));
    await reopen();
    p = (await required(first, key()));
    expect(p.stage, PaymentStage.pending);
    await expectLater(
      first.closePreflightRefused(p, active(p), refusal(p)),
      failure(PaymentLedgerFailure.stale),
    );
    await expectLater(
      first.beginPreflight(
        key(),
        p.revision,
        bitcoin,
        'blocked-${p.stage.name}',
      ),
      failure(PaymentLedgerFailure.stale),
    );
    p = await ok(first.recordUnknown(p, active(p)));
    await reopen();
    p = (await required(first, key()));
    expect(p.stage, PaymentStage.unknown);
    await expectLater(
      first.closePreflightRefused(p, active(p), refusal(p)),
      failure(PaymentLedgerFailure.stale),
    );
    await expectLater(
      first.beginPreflight(
        key(),
        p.revision,
        bitcoin,
        'blocked-${p.stage.name}',
      ),
      failure(PaymentLedgerFailure.stale),
    );
    await expectLater(
      first.beginPreflight(key(), p.revision, bitcoin, 'forbidden'),
      failure(PaymentLedgerFailure.stale),
    );
    await expectLater(
      first.sealFunding(p, active(p)),
      failure(PaymentLedgerFailure.stale),
    );
    p = await ok(first.recordPaid(p, active(p), receipt(p, 'paid-receipt')));
    await reopen();
    p = (await required(first, key()));
    expect(p.stage, PaymentStage.paid);
    await expectLater(
      first.closePreflightRefused(p, active(p), refusal(p)),
      failure(PaymentLedgerFailure.stale),
    );
    await expectLater(
      first.beginPreflight(
        key(),
        p.revision,
        bitcoin,
        'blocked-${p.stage.name}',
      ),
      failure(PaymentLedgerFailure.stale),
    );
    expect(
      (await ok(first.recordPaid(p, active(p), receipt(p, 'paid-receipt'))))
          .revision,
      p.revision,
    );
    await expectLater(
      first.recordPaid(p, active(p), receipt(p, 'conflicting-paid')),
      failure(PaymentLedgerFailure.conflict),
    );
    await expectLater(
      first.recordUnknown(p, active(p)),
      failure(PaymentLedgerFailure.stale),
    );
    await expectLater(
      first.beginPreflight(key(), p.revision, bitcoin, 'after-paid'),
      failure(PaymentLedgerFailure.stale),
    );
  });

  test(
    'lost create reply attaches correlation while remaining unknown',
    () async {
      var p = await preflight();
      p = await ok(first.sealCreate(p, active(p)));
      final staleCreate = p;
      p = await ok(first.recordUnknown(p, active(p)));
      await expectLater(
        first.linkCreated(staleCreate, active(staleCreate), 'boltz-id'),
        failure(PaymentLedgerFailure.stale),
      );
      p = await ok(first.linkCreated(p, active(p), 'boltz-id'));
      expect(p.stage, PaymentStage.unknown);
      await expectLater(
        first.linkCreated(p, active(p), 'different-id'),
        failure(PaymentLedgerFailure.stale),
      );
      await expectLater(
        first.sealFunding(p, active(p)),
        failure(PaymentLedgerFailure.stale),
      );
    },
  );

  test(
    'wrong network or operation receipts never mutate the payment',
    () async {
      final p = await funded();
      final bad = PaymentReceipt(
        network: NetworkEnv.regtest,
        operationId: active(p).operationId,
        walletId: liquid.walletId,
        backendReference: 'boltz-id',
        reference: 'wrong-network',
      );
      await expectLater(
        first.recordPaid(p, active(p), bad),
        failure(PaymentLedgerFailure.conflict),
      );
      expect((await required(first, key())).revision, p.revision);
    },
  );

  test('corrupt stored stage, pointer and JSON fail closed', () async {
    final p = await preflight();
    await db1.customStatement("UPDATE payments SET stage = 'unpaid'");
    await expectLater(
      second.read(key()),
      failure(PaymentLedgerFailure.recoveryRequired),
    );
    await db1.customStatement(
      "UPDATE payments SET stage = 'preflight', active_ordinal = 99",
    );
    await expectLater(
      first.read(key()),
      failure(PaymentLedgerFailure.recoveryRequired),
    );
    await db1.customStatement('UPDATE payments SET active_ordinal = 1');
    await db1.customStatement(
      "UPDATE payment_reviews SET sources = 'bad-json'",
    );
    await expectLater(
      first.sealCreate(p, active(p)),
      failure(PaymentLedgerFailure.recoveryRequired),
    );
    expect(
      (await db1.customSelect('SELECT revision FROM payments').getSingle())
          .read<int>('revision'),
      p.revision,
    );
  });

  test(
    'real SQLite writer contention is busy and cannot authorize an effect',
    () async {
      final p = await ok(first.createOrReadReview(request(), review));
      final locked = Completer<void>();
      final release = Completer<void>();
      final owner = db1.transaction(() async {
        await db1.customStatement('UPDATE payments SET revision = revision');
        locked.complete();
        await release.future;
      });
      await locked.future;
      try {
        await expectLater(
          second.beginPreflight(key(), p.revision, liquid, 'contended'),
          failure(PaymentLedgerFailure.busy),
        );
      } finally {
        release.complete();
        await owner;
      }
      final stored = (await required(first, key()));
      expect(stored.attemptCount, 0);
      expect(stored.revision, p.revision);
    },
  );

  test('version-one schema with the same column names but missing constraints is refused', () async {
    await db1.customStatement(
      'ALTER TABLE payment_attempts RENAME TO old_attempts',
    );
    await db1.customStatement(
      'CREATE TABLE payment_attempts AS SELECT * FROM old_attempts',
    );
    await reopen();
    await expectLater(
      first.read(key()),
      failure(PaymentLedgerFailure.recoveryRequired),
    );
  });

  test(
    'a version-one database missing its tables is recovery-required',
    () async {
      await db1.customStatement('DROP TABLE payment_attempts');
      await reopen();
      await expectLater(
        first.read(key()),
        failure(PaymentLedgerFailure.recoveryRequired),
      );
    },
  );
}
