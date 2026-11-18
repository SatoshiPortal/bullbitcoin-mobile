import 'dart:async';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/src/data/bark_ark_client.dart';
import 'package:ark/src/data/ark_store.dart';
import 'package:ark/src/domain/ark_execution_policy.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';

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
  test(
    'cold board quote refreshes its own session before observation',
    () async {
      expect(await client.create(config), isA<Ok>());
      native.requireBoardServerInfo = true;
      final result = await client.quote(
        account,
        ArkQuoteRequest.board(amount: Sats.fromInt(1000)),
      );
      expect(result, isA<Ok<ArkQuote, ArkWalletFailure>>());
      expect(native.boardServerEvents, ['server', 'observe', 'estimate-board']);
      expect(native.closes, native.opens);
      final snapshot = (await client.read(
        account,
      ) as Ok<ArkSnapshot, ArkWalletFailure>).value;
      expect(snapshot.serverInfo?.minimumBoard, Sats.fromInt(1000));
      expect(snapshot.operations, isEmpty);
      expect(native.executes, 0);
      expect(native.registrations, 0);
    },
  );

  test(
    'cold board funding revalidates with its own refreshed server',
    () async {
      expect(await client.create(config), isA<Ok>());
      native.requireBoardServerInfo = true;
      final quoted = await client.quote(
        account,
        ArkQuoteRequest.board(amount: Sats.fromInt(1000)),
      );
      final quote = (quoted as Ok<ArkQuote, ArkWalletFailure>).value;
      native.boardServerEvents.clear();
      final prepared = await client.submit(
        account,
        ArkSubmission.boardFunding(
          quoteId: quote.id,
          operationId: 'cold-board',
        ),
      );
      expect(prepared, isA<Ok<ArkOperation, ArkWalletFailure>>());
      expect(native.boardServerEvents, ['server', 'observe', 'estimate-board']);
      final snapshot = (await client.read(
        account,
      ) as Ok<ArkSnapshot, ArkWalletFailure>).value;
      expect(snapshot.operations.single.id, 'cold-board');
      expect(native.closes, native.opens);
      expect(native.executes, 0);
      expect(native.registrations, 0);
    },
  );

  for (final revokeBudget in [false, true]) {
    test(
      'cold board server refusal budget=$revokeBudget cannot use old observation',
      () async {
        expect(await client.create(config), isA<Ok>());
        native.requireBoardServerInfo = true;
        if (revokeBudget) {
          native.afterStage = (name) {
            if (name == 'server') budget.allowed = false;
          };
        } else {
          native.failingStage = 'server';
        }
        final result = await client.quote(
          account,
          ArkQuoteRequest.board(amount: Sats.fromInt(1000)),
        );
        expect(result, isA<Err<ArkQuote, ArkWalletFailure>>());
        expect(native.boardServerEvents, ['server']);
        expect(native.closes, native.opens);
        expect(native.executes, 0);
        expect(native.registrations, 0);
      },
    );
  }

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
  for (final mode in ArkExecutionMode.values) {
    test(
      'disabled policy blocks renewal synchronization before capabilities in $mode',
      () async {
        expect(await client.create(config), isA<Ok>());
        await client.close();
        client = build(mode: mode);
        final derivations = child.calls;
        final opens = native.opens;
        final probes = preflight.calls;
        final executes = native.executes;
        expect(derivations, 1);
        expect(opens, 1);
        expect(probes, 1);
        policy.allowed = false;
        expect(budget.allowed, isTrue);
        expect(
          await client.synchronize(account, renew: true),
          isA<Err<ArkPassOutcome, ArkWalletFailure>>(),
        );
        expect(child.calls, derivations);
        expect(native.opens, opens);
        expect(preflight.calls, probes);
        expect(native.executes, executes);
        expect(native.broadcasts, 0);
        expect(native.registrations, 0);
      },
    );
  }
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
  ArkVtxo item(
    String id, {
    ArkVtxoState state = ArkVtxoState.spendable,
    bool pending = false,
  }) => ArkVtxo(
    id: id,
    amount: Sats.fromInt(10000),
    expiryHeight: 1100,
    state: state,
    pendingRound: pending,
  );
  test(
    'positively observed ids during partial passes remain durable obligations',
    () async {
      native.inventoryOverride = [item('a')];
      await client.create(config);
      native.inventoryOverride = [item('a'), item('b')];
      native.failingStage = 'server';
      await client.synchronize(account, renew: false);
      native.inventoryOverride = [item('a')];
      native.failingStage = null;
      for (var i = 0; i < 2; i++) {
        await client.close();
        client = build();
        final result = await client.synchronize(account, renew: false);
        final snapshot =
            (result as Ok<ArkPassOutcome, ArkWalletFailure>).value.snapshot;
        expect(snapshot.vtxoInventoryComplete, isFalse);
        expect(snapshot.vtxos.any((v) => v.id == 'b'), isTrue);
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
      }
    },
  );
  for (final state in [
    ArkVtxoState.unknown,
    ArkVtxoState.locked,
    ArkVtxoState.spent,
    ArkVtxoState.spendable,
  ]) {
    test(
      'renewal cannot retire old expiry from unusable or pending output $state',
      () async {
        native.inventoryOverride = [item('a')];
        await client.create(config);
        native.inventoryOverride = [
          item('a', state: ArkVtxoState.spent),
          item('r', state: state, pending: state == ArkVtxoState.spendable),
        ];
        native.movementEvidence = [
          ArkMovement(
            id: 'renew',
            kind: ArkMovementKind.renewal,
            status: ArkMovementStatus.successful,
            inputVtxoIds: ['a'],
            outputVtxoIds: ['r'],
          ),
        ];
        for (var i = 0; i < 2; i++) {
          final result = await client.synchronize(account, renew: false);
          expect(
            (result as Ok<ArkPassOutcome, ArkWalletFailure>)
                .value
                .snapshot
                .vtxoInventoryComplete,
            isFalse,
          );
          await client.close();
          client = build();
        }
      },
    );
  }
  for (final weakness in [
    'stale',
    'incomplete',
    'delegated',
    'stage-failure',
    'recovery',
  ]) {
    test(
      'renewal retirement refuses $weakness evidence across restart',
      () async {
        native.inventoryOverride = [item('a')];
        await client.create(config);
        native.inventoryOverride = [
          item('a', state: ArkVtxoState.spent),
          item('r'),
        ];
        native.movementEvidence = [
          ArkMovement(
            id: 'renew',
            kind: ArkMovementKind.renewal,
            status: ArkMovementStatus.successful,
            inputVtxoIds: ['a'],
            outputVtxoIds: ['r'],
          ),
        ];
        native.observationStale = weakness == 'stale';
        native.inventoryCompleteness = weakness == 'incomplete'
            ? ArkSectionCompleteness.incomplete
            : ArkSectionCompleteness.complete;
        native.renewalStatus = weakness == 'delegated'
            ? ArkRenewalStatus.delegated
            : ArkRenewalStatus.due;
        native.failingStage = weakness == 'stage-failure' ? 'server' : null;
        if (weakness == 'recovery') {
          final store = ArkStore.open(
            '${ArkStore.accountPath(temp.path, account)}/state.sqlite',
            create: false,
          );
          store.put('recovery', {'status': ArkRecoveryStatus.incomplete.name});
          store.close();
        }
        for (var i = 0; i < 2; i++) {
          final result = await client.synchronize(account, renew: false);
          final snapshot =
              (result as Ok<ArkPassOutcome, ArkWalletFailure>).value.snapshot;
          expect(snapshot.vtxoInventoryComplete, isFalse);
          expect(
            snapshot.vtxos.singleWhere((v) => v.id == 'a').state,
            ArkVtxoState.unknown,
          );
          await client.close();
          client = build();
        }
      },
    );
  }
  test(
    'authoritative usable renewal replacement retires old inventory durably',
    () async {
      native.inventoryOverride = [item('a')];
      await client.create(config);
      native.inventoryOverride = [
        item('a', state: ArkVtxoState.spent),
        item('r'),
      ];
      native.movementEvidence = [
        ArkMovement(
          id: 'renew',
          kind: ArkMovementKind.renewal,
          status: ArkMovementStatus.successful,
          inputVtxoIds: ['a'],
          outputVtxoIds: ['r'],
        ),
      ];
      final result = await client.synchronize(account, renew: false);
      final snapshot =
          (result as Ok<ArkPassOutcome, ArkWalletFailure>).value.snapshot;
      expect(snapshot.vtxoInventoryComplete, isTrue);
      final store = ArkStore.open(
        '${ArkStore.accountPath(temp.path, account)}/state.sqlite',
        create: false,
      );
      expect(
        store.get('inventory-retirements')?['a'],
        containsPair('movement', 'renew'),
      );
      store.close();
      native.inventoryOverride = [item('r')];
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
    },
  );
  test('inventory and snapshot logical writes roll back together on persistence failure', () async {
    native.inventoryOverride = [item('a')];
    await client.create(config);
    final path = '${ArkStore.accountPath(temp.path, account)}/state.sqlite';
    final before = ArkStore.open(path, create: false);
    final baseline = before.get('complete-inventory');
    final retained = before.get('inventory-obligations');
    final retirements = before.get('inventory-retirements');
    final revision = before.snapshot?.revision;
    final seen = <ArkSnapshot>[];
    final subscribed = Completer<void>();
    final subscription = client.watch(account).listen((event) {
      if (event case Ok(:final value)) {
        seen.add(value);
        if (!subscribed.isCompleted) subscribed.complete();
      }
    });
    await subscribed.future;
    before.close();
    native.inventoryOverride = [
      item('a', state: ArkVtxoState.spent),
      item('r'),
    ];
    native.movementEvidence = [
      ArkMovement(
        id: 'renew',
        kind: ArkMovementKind.renewal,
        status: ArkMovementStatus.successful,
        inputVtxoIds: ['a'],
        outputVtxoIds: ['r'],
      ),
    ];
    final db = sqlite3.open(path);
    db.execute(
      "CREATE TRIGGER deny_snapshot BEFORE INSERT ON state WHEN NEW.key='snapshot' BEGIN SELECT RAISE(ABORT,'test interruption'); END",
    );
    try {
      expect(await client.synchronize(account, renew: false), isA<Err>());
    } finally {
      db.execute('DROP TRIGGER deny_snapshot');
      db.close();
    }
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(seen.every((s) => s.revision == revision), isTrue);
    await client.close();
    client = build();
    final persisted = await client.read(account);
    expect(
      (persisted as Ok<ArkSnapshot, ArkWalletFailure>).value.revision,
      revision,
    );
    final reopened = ArkStore.open(path, create: false);
    expect(reopened.get('inventory-obligations'), retained);
    expect(reopened.get('inventory-retirements'), retirements);
    expect(reopened.get('complete-inventory'), baseline);
    expect(reopened.snapshot?.vtxos.single.id, 'a');
    reopened.close();
  });
  for (final status in [
    ArkOperationStatus.prepared,
    ArkOperationStatus.pending,
  ]) {
    test(
      '$status operation pins original provider before native reopening',
      () async {
        final withFallback = ArkAccountConfig(
          id: account,
          arkUrl: config.arkUrl,
          primaryEsploraUrl: config.primaryEsploraUrl,
          fallbackEsploraUrl: Uri.parse('http://localhost:3001'),
        );
        await client.create(withFallback);
        final store = ArkStore.open(
          '${ArkStore.accountPath(temp.path, account)}/state.sqlite',
          create: false,
        );
        store.saveOperation(
          ArkOperation(
            id: 'pending-board',
            kind: ArkOperationKind.board,
            status: status,
            chainSource: config.primaryEsploraUrl,
            configGeneration: 1,
          ),
          'board-quote',
        );
        store.close();
        final opens = native.opens;
        preflight.primaryUnreachable = true;
        expect(await client.synchronize(account, renew: false), isA<Err>());
        expect(preflight.requiredSources.last, config.primaryEsploraUrl);
        expect(native.opens, opens);
      },
    );
  }
  test('exit admission failure rolls back authority and retries original quote safely', () async {
    await client.create(config);
    final result = await client.quote(
      account,
      ArkQuoteRequest.emergencyExit(
        ids: [FakeOpener.firstId],
        destination: 'destination',
        feeRate: FeeRate(1),
        maxClaimFee: Sats.fromInt(100),
      ),
    );
    final quote = (result as Ok<ArkQuote, ArkWalletFailure>).value;
    final path = '${ArkStore.accountPath(temp.path, account)}/state.sqlite';
    final db = sqlite3.open(path);
    db.execute(
      "CREATE TRIGGER deny_admission BEFORE INSERT ON operations BEGIN SELECT RAISE(ABORT,'test admission interruption'); END",
    );
    try {
      expect(
        await client.submit(
          account,
          ArkSubmission.confirmQuote(quoteId: quote.id, operationId: 'exit'),
        ),
        isA<Err>(),
      );
      expect(native.executes, 0);
    } finally {
      db.execute('DROP TRIGGER deny_admission');
      db.close();
    }
    await client.close();
    client = build();
    final store = ArkStore.open(path, create: false);
    expect(
      store.claimAuthority(quote.selectedIds, 'destination', Sats.fromInt(100)),
      isNull,
    );
    expect(store.operation('exit'), isNull);
    store.close();
    expect(
      await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: quote.id, operationId: 'exit'),
      ),
      isA<Ok>(),
    );
    expect(native.executes, 1);
    final reopened = ArkStore.open(path, create: false);
    expect(
      reopened.claimAuthority(
        quote.selectedIds,
        'destination',
        Sats.fromInt(100),
      ),
      'exit',
    );
    expect(reopened.operation('exit')?.binding, quote.id);
    reopened.close();
  });
  test(
    'expired Board funding reports a stale quote before registration',
    () async {
      expect(await client.create(config), isA<Ok>());
      final quoted = await client.quote(
        account,
        ArkQuoteRequest.board(amount: Sats.fromInt(20000)),
      );
      final quote = (quoted as Ok<ArkQuote, ArkWalletFailure>).value;
      native.boardExpiry = native.tip;
      final result = await client.submit(
        account,
        ArkSubmission.boardFunding(
          quoteId: quote.id,
          operationId: 'expired-board',
        ),
      );
      expect(result, isA<Err<ArkOperation, ArkWalletFailure>>());
      expect(
        (result as Err<ArkOperation, ArkWalletFailure>).failure,
        isA<ArkStaleQuoteFailure>(),
      );
      final retry = await client.submit(
        account,
        ArkSubmission.boardFunding(
          quoteId: quote.id,
          operationId: 'expired-board',
        ),
      );
      expect(
        retry,
        isA<Err<ArkOperation, ArkWalletFailure>>(),
        reason: 'A retry must not return Ok with no funding tuple',
      );
      expect(
        (retry as Err<ArkOperation, ArkWalletFailure>).failure,
        isA<ArkStaleQuoteFailure>(),
      );
      final store = ArkStore.open(
        '${ArkStore.accountPath(temp.path, account)}/state.sqlite',
        create: false,
      );
      try {
        expect(
          store.operation('expired-board')?.operation.status,
          ArkOperationStatus.failed,
        );
      } finally {
        store.close();
      }
      expect(native.fundings, 1);
      expect(native.registrations, 0);
      expect(native.broadcasts, 0);
    },
  );
  for (final failure in ['prepare', 'verify']) {
    test(
      'claim $failure failure before commit releases only the operation hold',
      () async {
        expect(await client.create(config), isA<Ok>());
        final exitResult = await client.quote(
          account,
          ArkQuoteRequest.emergencyExit(
            ids: [FakeOpener.firstId],
            destination: 'destination',
            feeRate: FeeRate(1),
            maxClaimFee: Sats.fromInt(100),
          ),
        );
        final exit = (exitResult as Ok<ArkQuote, ArkWalletFailure>).value;
        expect(
          await client.submit(
            account,
            ArkSubmission.confirmQuote(quoteId: exit.id, operationId: 'exit'),
          ),
          isA<Ok>(),
        );
        final request = ArkQuoteRequest.claim(
          ids: [FakeOpener.firstId],
          destination: 'destination',
          maxFee: Sats.fromInt(100),
        );
        final quoted = await client.quote(account, request);
        final quote = (quoted as Ok<ArkQuote, ArkWalletFailure>).value;
        if (failure == 'prepare') {
          native.claimPreparer = (_) async =>
              throw Exception('prepare unavailable');
        }
        verifier.wrongInputs = failure == 'verify';
        expect(
          await client.submit(
            account,
            ArkSubmission.confirmQuote(
              quoteId: quote.id,
              operationId: 'failed-claim',
            ),
          ),
          isA<Err>(),
        );
        expect(native.broadcasts, 0);
        final store = ArkStore.open(
          '${ArkStore.accountPath(temp.path, account)}/state.sqlite',
          create: false,
        );
        try {
          expect(
            store.operation('failed-claim')?.operation.status,
            ArkOperationStatus.failed,
          );
          expect(store.operation('failed-claim')?.evidence?['raw'], isNull);
          expect(
            store.claimAuthority(
              [FakeOpener.firstId],
              'destination',
              Sats.fromInt(100),
            ),
            'exit',
          );
        } finally {
          store.close();
        }
        native.claimPreparer = null;
        verifier.wrongInputs = false;
        final retried = await client.quote(account, request);
        final retry = (retried as Ok<ArkQuote, ArkWalletFailure>).value;
        expect(
          await client.submit(
            account,
            ArkSubmission.confirmQuote(
              quoteId: retry.id,
              operationId: 'retry-claim',
            ),
          ),
          isA<Ok>(),
        );
        expect(native.broadcasts, 1);
      },
    );
  }
}
