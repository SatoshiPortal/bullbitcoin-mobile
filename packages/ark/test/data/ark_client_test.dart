import 'dart:async';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/src/data/bark_ark_client.dart';
import 'package:ark/src/data/ark_store.dart';
import 'package:ark/src/domain/ark_execution_policy.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import '../support/fake_native.dart';

void main() {
  late Directory temp;
  late FakeOpener native;
  late FakeChild child;
  late FakeBudget budget;
  late FakePolicy policy;
  late FakeVerifier verifier;
  late FakePreflight preflight;
  late BarkArkClient client;
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );
  final config = ArkAccountConfig(
    id: account,
    arkUrl: Uri.parse('http://localhost:3535'),
    primaryEsploraUrl: Uri.parse('http://localhost:3000'),
  );
  final clock = DateTime.utc(2026, 11, 16);
  BarkArkClient build({ArkExecutionMode mode = ArkExecutionMode.foreground}) =>
      BarkArkClient(
        storagePath: temp.path,
        childProvider: child,
        transactionVerifier: verifier,
        executionPolicy: policy,
        executionMode: mode,
        stageBudget: budget,
        opener: native,
        preflight: preflight,
        clock: () => clock,
      );
  setUp(() {
    temp = Directory.systemTemp.createTempSync('ark-client-');
    native = FakeOpener();
    child = FakeChild();
    budget = FakeBudget();
    policy = FakePolicy();
    verifier = FakeVerifier();
    preflight = FakePreflight();
    client = build();
  });
  tearDown(() async {
    await client.close();
    temp.deleteSync(recursive: true);
  });
  Future<ArkQuote> paymentQuote() async {
    final result = await client.quote(
      account,
      ArkQuoteRequest.payment(
        destination: ArkPaymentDestination(
          kind: ArkDestinationKind.ark,
          value: 'address',
        ),
        amount: Sats.fromInt(1000),
      ),
    );
    expect(result, isA<Ok>());
    return (result as Ok<ArkQuote, ArkWalletFailure>).value;
  }

  test(
    'projection reads never open native; child is scoped to each writer pass',
    () async {
      expect(await client.create(config), isA<Ok>());
      final count = native.opens;
      expect(await client.read(account), isA<Ok>());
      expect(native.opens, count);
      expect(child.calls, 1);
      expect(native.closes, native.opens);
      await client.synchronize(account, renew: false);
      expect(child.calls, 2);
      expect(native.closes, native.opens);
    },
  );
  test(
    'existing-only cannot create and missing metadata remains absent',
    () async {
      await client.close();
      client = build(mode: ArkExecutionMode.backgroundExisting);
      expect(await client.create(config), isA<Err>());
      expect(await client.synchronize(account, renew: true), isA<Err>());
      expect(native.opens, 0);
      expect(temp.listSync(), isEmpty);
    },
  );
  test(
    'ambiguous payment is never replayed; read/sync reconcile after restart',
    () async {
      await client.create(config);
      final quote = await paymentQuote();
      native.failExecute = true;
      final first = await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: quote.id, operationId: 'payment'),
      );
      expect(first, isA<Ok>());
      expect(
        (first as Ok<ArkOperation, ArkWalletFailure>).value.status,
        ArkOperationStatus.outcomeUnknown,
      );
      await client.close();
      client = build();
      final read = await client.read(account);
      expect(
        (read as Ok<ArkSnapshot, ArkWalletFailure>)
            .value
            .operations
            .single
            .status,
        ArkOperationStatus.outcomeUnknown,
      );
      expect(
        await client.submit(
          account,
          ArkSubmission.confirmQuote(quoteId: quote.id, operationId: 'payment'),
        ),
        isA<Ok>(),
      );
      expect(native.executes, 1);
      native.reconcileSuccess = true;
      final pass = await client.synchronize(account, renew: false);
      expect(
        (pass as Ok<ArkPassOutcome, ArkWalletFailure>)
            .value
            .snapshot
            .operations
            .single
            .status,
        ArkOperationStatus.succeeded,
      );
      expect(native.executes, 1);
    },
  );
  test('same operation id with different quote is refused', () async {
    await client.create(config);
    final first = await paymentQuote();
    await client.submit(
      account,
      ArkSubmission.confirmQuote(quoteId: first.id, operationId: 'payment'),
    );
    final second = await paymentQuote();
    expect(
      await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: second.id, operationId: 'payment'),
      ),
      isA<Err>(),
    );
    expect(native.executes, 1);
  });
  test('tip change invalidates review before native spend', () async {
    await client.create(config);
    final quote = await paymentQuote();
    native.tip++;
    expect(
      await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: quote.id, operationId: 'stale'),
      ),
      isA<Err>(),
    );
    expect(native.executes, 0);
  });
  test(
    'close waits for admitted stage; another client cannot open concurrently',
    () async {
      await client.create(config);
      native.stageEntered = Completer();
      native.releaseStage = Completer();
      final pass = client.synchronize(account, renew: false);
      await native.stageEntered?.future;
      var closed = false;
      final close = client.close().then((_) {
        closed = true;
      });
      final competitor = build();
      expect(await competitor.synchronize(account, renew: false), isA<Err>());
      await competitor.close();
      expect(closed, isFalse);
      expect(native.closes, native.opens - 1);
      native.releaseStage?.complete();
      await pass;
      await close;
      expect(closed, isTrue);
      expect(native.closes, native.opens);
    },
  );
  test(
    'budget revokes next stage and returns stale partial observation',
    () async {
      await client.create(config);
      native.afterStage = (name) {
        if (name == 'ark') budget.allowed = false;
      };
      final result = await client.synchronize(account, renew: true);
      final outcome = (result as Ok<ArkPassOutcome, ArkWalletFailure>).value;
      expect(outcome.failedStages, contains('deferred'));
      expect(outcome.snapshot.stale, isTrue);
      expect(outcome.snapshot.vtxoInventoryComplete, isFalse);
      expect(native.executes, 0);
      expect(native.closes, native.opens);
    },
  );
  test(
    'missing formerly live vtxo cannot become complete empty evidence',
    () async {
      await client.create(config);
      native.missingVtxos = true;
      final result = await client.synchronize(account, renew: false);
      final snapshot =
          (result as Ok<ArkPassOutcome, ArkWalletFailure>).value.snapshot;
      expect(snapshot.vtxoInventoryComplete, isFalse);
      expect(snapshot.stale, isTrue);
    },
  );
  test('board requires reviewed quote and exact journalled tuple; signed PSBT refused', () async {
    await client.create(config);
    final quoted = await client.quote(
      account,
      ArkQuoteRequest.board(amount: Sats.fromInt(1000)),
    );
    final quote = (quoted as Ok<ArkQuote, ArkWalletFailure>).value;
    expect(
      await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: quote.id, operationId: 'invalid'),
      ),
      isA<Err>(),
    );
    final funding = await client.submit(
      account,
      ArkSubmission.boardFunding(operationId: 'board', quoteId: quote.id),
    );
    expect(funding, isA<Ok>());
    expect(
      await client.submit(
        account,
        ArkSubmission.registerBoard(
          operationId: 'board',
          unfinalisedPsbt: 'public',
          keypairIndex: 5,
          expiryHeight: 2000,
        ),
      ),
      isA<Err>(),
    );
    verifier.finalised = true;
    expect(
      await client.submit(
        account,
        ArkSubmission.registerBoard(
          operationId: 'board',
          unfinalisedPsbt: 'public',
          keypairIndex: 4,
          expiryHeight: 2000,
        ),
      ),
      isA<Err>(),
    );
    expect(native.registrations, 0);
    expect(native.broadcasts, 0);
    verifier.finalised = false;
    expect(
      await client.submit(
        account,
        ArkSubmission.registerBoard(
          operationId: 'board',
          unfinalisedPsbt: 'public',
          keypairIndex: 4,
          expiryHeight: 2000,
        ),
      ),
      isA<Ok>(),
    );
    expect(native.registrations, 1);
    expect(native.broadcasts, 0);
  });
  test('claim verifies PSBT input evidence before any broadcast', () async {
    await client.create(config);
    final exitQuote = await client.quote(
      account,
      ArkQuoteRequest.emergencyExit(
        ids: [FakeOpener.firstId],
        destination: 'destination',
        feeRate: FeeRate(1),
        maxClaimFee: Sats.fromInt(100),
      ),
    );
    final exit = (exitQuote as Ok<ArkQuote, ArkWalletFailure>).value;
    await client.submit(
      account,
      ArkSubmission.confirmQuote(quoteId: exit.id, operationId: 'exit'),
    );
    final claimQuote = await client.quote(
      account,
      ArkQuoteRequest.claim(
        ids: [FakeOpener.firstId],
        destination: 'destination',
        maxFee: Sats.fromInt(100),
      ),
    );
    final claim = (claimQuote as Ok<ArkQuote, ArkWalletFailure>).value;
    verifier.wrongInputs = true;
    expect(
      await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: claim.id, operationId: 'claim'),
      ),
      isA<Err>(),
    );
    expect(native.broadcasts, 0);
    expect(
      await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: claim.id, operationId: 'claim'),
      ),
      isA<Ok>(),
    );
    expect(native.broadcasts, 0);
  });
  test(
    'verified claim journals exact signed transaction before one broadcast',
    () async {
      await client.create(config);
      final exitQuote = await client.quote(
        account,
        ArkQuoteRequest.emergencyExit(
          ids: [FakeOpener.firstId],
          destination: 'destination',
          feeRate: FeeRate(1),
          maxClaimFee: Sats.fromInt(100),
        ),
      );
      final exit = (exitQuote as Ok<ArkQuote, ArkWalletFailure>).value;
      await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: exit.id, operationId: 'exit'),
      );
      final quoted = await client.quote(
        account,
        ArkQuoteRequest.claim(
          ids: [FakeOpener.firstId],
          destination: 'destination',
          maxFee: Sats.fromInt(100),
        ),
      );
      final quote = (quoted as Ok<ArkQuote, ArkWalletFailure>).value;
      final result = await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: quote.id, operationId: 'claim'),
      );
      final operation = (result as Ok<ArkOperation, ArkWalletFailure>).value;
      expect(operation.status, ArkOperationStatus.pending);
      expect(operation.actualIds, [FakeOpener.firstId]);
      expect(native.broadcasts, 1);
      await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: quote.id, operationId: 'claim'),
      );
      expect(native.broadcasts, 1);
      expect(
        await client.submit(
          account,
          ArkSubmission.confirmQuote(
            quoteId: quote.id,
            operationId: 'different-id',
          ),
        ),
        isA<Err>(),
      );
      expect(native.broadcasts, 1);
    },
  );
  test(
    'disabled execution policy performs no derivation or native open',
    () async {
      policy.allowed = false;
      expect(await client.create(config), isA<Err>());
      expect(child.calls, 0);
      expect(native.opens, 0);
      expect(temp.listSync(), isEmpty);
    },
  );
  test(
    'malformed persisted projection fails closed as storage failure',
    () async {
      await client.create(config);
      final store = ArkStore.open(
        '${ArkStore.accountPath(temp.path, account)}/state.sqlite',
        create: false,
      );
      store.put('snapshot', {'revision': true});
      store.close();
      expect(
        await client.read(account),
        isA<Err<ArkSnapshot, ArkWalletFailure>>(),
      );
      expect(native.opens, 1);
    },
  );
  test('foreground creation resumes after preflight failed before native admission', () async {
    preflight.failuresRemaining = 1;
    expect(await client.create(config), isA<Err>());
    expect(native.opens, 0);
    final background = build(mode: ArkExecutionMode.backgroundExisting);
    expect(await background.synchronize(account, renew: true), isA<Err>());
    expect(native.opens, 0);
    await background.close();
    expect(await client.create(config), isA<Ok>());
    expect(native.creates, 1);
    expect(await client.create(config), isA<Ok>());
    expect(native.creates, 1);
  });
  test(
    'child-provider failure leaves an explicit foreground create retry',
    () async {
      child.failOnce = true;
      expect(await client.create(config), isA<Err>());
      expect(native.opens, 0);
      expect(await client.create(config), isA<Ok>());
      expect(native.creates, 1);
    },
  );
  for (final recovery in [
    ArkRecoveryStatus.complete,
    ArkRecoveryStatus.failed,
    ArkRecoveryStatus.incomplete,
  ]) {
    test(
      'open outcome $recovery persists before scan and snapshot failure',
      () async {
        native.recovery = recovery;
        native.failInitialScan = true;
        expect(await client.create(config), isA<Err>());
        final store = ArkStore.open(
          '${ArkStore.accountPath(temp.path, account)}/state.sqlite',
          create: false,
        );
        expect(store.snapshot, isNull);
        expect(store.get('recovery')?['status'], recovery.name);
        store.close();
        await client.close();
        client = build();
        final retried = await client.create(config);
        expect(
          (retried as Ok<ArkSnapshot, ArkWalletFailure>).value.recovery,
          recovery,
        );
        expect(native.creates, 1);
      },
    );
  }
  test('native return interrupted before callback stays unknown without recreating', () async {
    native.failBeforeRecoveryCallback = true;
    expect(await client.create(config), isA<Err>());
    await client.close();
    client = build();
    final retried = await client.create(config);
    expect(
      (retried as Ok<ArkSnapshot, ArkWalletFailure>).value.recovery,
      ArkRecoveryStatus.unknown,
    );
    expect(native.creates, 1);
    expect(
      await client.quote(
        account,
        ArkQuoteRequest.payment(
          destination: ArkPaymentDestination(
            kind: ArkDestinationKind.ark,
            value: 'address',
          ),
          amount: Sats.fromInt(1000),
        ),
      ),
      isA<Err>(),
    );
  });
  for (final spent in [false, true]) {
    test(
      'incomplete ${spent ? 'spent' : 'missing'} evidence survives repeated pass and restart',
      () async {
        await client.create(config);
        native.missingVtxos = !spent;
        native.spentWithoutEvidence = spent;
        for (var pass = 0; pass < 3; pass++) {
          if (pass == 1) {
            await client.close();
            client = build();
          }
          final result = await client.synchronize(account, renew: false);
          final value =
              (result as Ok<ArkPassOutcome, ArkWalletFailure>).value.snapshot;
          expect(
            value.vtxoInventoryComplete,
            isFalse,
            reason: 'unresolved evidence on pass $pass',
          );
          expect(value.stale, isTrue);
        }
      },
    );
  }
  test('failed pass never publishes an intermediate fresh snapshot', () async {
    await client.create(config);
    final initial = await client.read(account);
    final revision =
        (initial as Ok<ArkSnapshot, ArkWalletFailure>).value.revision;
    final seen = <ArkSnapshot>[];
    final subscribed = Completer<void>();
    final subscription = client.watch(account).listen((value) {
      if (value case Ok(:final value)) {
        seen.add(value);
        if (!subscribed.isCompleted) subscribed.complete();
      }
    });
    await subscribed.future;
    native.failingStage = 'server';
    await client.synchronize(account, renew: false);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(seen.where((s) => s.revision > revision), isNotEmpty);
    expect(
      seen.where((s) => s.revision > revision).every((s) => s.stale),
      isTrue,
    );
  });
  test('positive recorded spend settles preserved missing inventory across restart', () async {
    await client.create(config);
    native.missingVtxos = true;
    await client.synchronize(account, renew: false);
    await client.close();
    client = build();
    native.movementEvidence = [
      ArkMovement(
        id: 'observed-spend',
        kind: ArkMovementKind.payment,
        status: ArkMovementStatus.successful,
        inputVtxoIds: [FakeOpener.firstId, FakeOpener.secondId],
      ),
    ];
    final result = await client.synchronize(account, renew: false);
    expect(
      (result as Ok<ArkPassOutcome, ArkWalletFailure>)
          .value
          .snapshot
          .vtxoInventoryComplete,
      isTrue,
    );
    native.movementEvidence = [];
    await client.close();
    client = build();
    final repeated = await client.synchronize(account, renew: false);
    expect(
      (repeated as Ok<ArkPassOutcome, ArkWalletFailure>)
          .value
          .snapshot
          .vtxoInventoryComplete,
      isTrue,
    );
  });
  test(
    'lost native files after a persisted opening outcome refuse recreation',
    () async {
      native.failInitialScan = true;
      expect(await client.create(config), isA<Err>());
      expect(native.creates, 1);
      final opened = native.opens;
      native.exists = false;
      expect(await client.create(config), isA<Err>());
      expect(native.opens, opened);
      expect(native.creates, 1);
    },
  );
}
