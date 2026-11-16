import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_store.dart';
import 'package:ark/src/data/ark_claim_delivery.dart';
import 'package:ark/src/data/ark_native_session.dart';
import 'package:ark/src/data/bark_native_opener.dart';
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:ark/src/data/bark_ark_client.dart';
import 'package:ark/src/domain/ark_execution_policy.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../support/fake_native.dart';

void main() {
  late Directory temp;
  late BarkArkClient client;
  late FakeOpener native;
  late FakeChild child;
  late FakeVerifier verifier;
  late DateTime clock;
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );
  late ArkAccountConfig config;
  final defaultConfig = ArkAccountConfig(
    id: account,
    arkUrl: Uri.parse('http://localhost:3535'),
    primaryEsploraUrl: Uri.parse('http://localhost:3000'),
  );
  String path() => '${ArkStore.accountPath(temp.path, account)}/state.sqlite';
  setUp(() {
    temp = Directory.systemTemp.createTempSync('ark-saved-claim-');
    native = FakeOpener();
    child = FakeChild();
    verifier = FakeVerifier();
    clock = DateTime.utc(2026);
    config = defaultConfig;
    client = BarkArkClient(
      storagePath: temp.path,
      childProvider: child,
      transactionVerifier: verifier,
      executionPolicy: FakePolicy(),
      executionMode: ArkExecutionMode.foreground,
      stageBudget: FakeBudget(),
      opener: native,
      preflight: FakePreflight(),
      clock: () => clock,
    );
  });
  tearDown(() async {
    await client.close();
    temp.deleteSync(recursive: true);
  });
  Future<void> signedClaim({
    List<String>? selected,
    bool succeeds = true,
  }) async {
    expect(await client.create(config), isA<Ok>());
    final exitResult = await client.quote(
      account,
      ArkQuoteRequest.emergencyExit(
        ids: selected ?? [FakeOpener.firstId],
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
    final result = await client.quote(
      account,
      ArkQuoteRequest.claim(
        ids: selected ?? [FakeOpener.firstId],
        destination: 'destination',
        maxFee: Sats.fromInt(100),
      ),
    );
    final claim = (result as Ok<ArkQuote, ArkWalletFailure>).value;
    expect(
      await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: claim.id, operationId: 'claim'),
      ),
      succeeds ? isA<Ok>() : isA<Err>(),
    );
  }

  test('projection derives exact signed summary after quote expiry without native or child opening', () async {
    await signedClaim();
    clock = clock.add(const Duration(days: 1));
    final opens = native.opens;
    final children = child.calls;
    final result = await client.read(account);
    final snapshot = (result as Ok<ArkSnapshot, ArkWalletFailure>).value;
    final claim = snapshot.operations.singleWhere((op) => op.id == 'claim');
    expect(claim.claimRecovery?.txid, 'd' * 64);
    expect(claim.claimRecovery?.destination, 'destination');
    expect(claim.claimRecovery?.net, Sats.fromInt(9990));
    expect(claim.claimRecovery?.fee, Sats.fromInt(10));
    expect(claim.actualIds, [FakeOpener.firstId]);
    expect(native.opens, opens);
    expect(child.calls, children);
    expect(native.broadcasts, 1);
  });
  for (final field in [
    'raw',
    'signedPsbt',
    'account',
    'fee',
    'net',
    'operationId',
    'quoteId',
    'source',
    'configGeneration',
    'inputAmounts',
  ]) {
    test('projection refuses corrupted committed claim $field', () async {
      await signedClaim();
      final db = sqlite3.open(path());
      final row = db
          .select("SELECT evidence FROM operations WHERE id='claim'")
          .single;
      final evidence =
          (jsonDecode(row['evidence'] as String) as Map<String, dynamic>);
      evidence[field] = 'corrupt';
      db.execute("UPDATE operations SET evidence=? WHERE id='claim'", [
        jsonEncode(evidence),
      ]);
      db.close();
      expect(await client.read(account), isA<Err>());
      expect(native.broadcasts, 1);
    });
  }
  group('keyless delivery', () {
    late HttpServer endpoint;
    final posts = <String>[];
    late FakePolicy policy;
    late FakeBudget budget;
    late FakePreflight preflight;
    late Completer<void> entered;
    Completer<void>? hold;
    var status = 200;
    var reply = '';
    Future<void> background({
      Duration deadline = const Duration(seconds: 15),
      ArkTransactionVerifierPort? check,
    }) async {
      await client.close();
      client = BarkArkClient(
        storagePath: temp.path,
        childProvider: child,
        transactionVerifier: check ?? verifier,
        executionPolicy: policy,
        executionMode: ArkExecutionMode.backgroundExisting,
        stageBudget: budget,
        opener: native,
        preflight: preflight,
        claimDelivery: HttpArkClaimDelivery(deadline: deadline),
        clock: () => clock,
      );
    }

    setUp(() async {
      posts.clear();
      policy = FakePolicy();
      budget = FakeBudget();
      preflight = FakePreflight();
      entered = Completer<void>();
      hold = null;
      status = 200;
      reply = 'd' * 64;
      endpoint = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      config = ArkAccountConfig(
        id: account,
        arkUrl: defaultConfig.arkUrl,
        primaryEsploraUrl: Uri.parse(
          'http://127.0.0.1:${endpoint.port}/configured',
        ),
      );
      endpoint.listen((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/configured/tx');
        posts.add(await utf8.decoder.bind(request).join());
        final store = ArkStore.open(path(), create: false, readOnly: true);
        expect(store.get('claim-delivery:claim')?['count'], greaterThan(0));
        store.close();
        if (!entered.isCompleted) entered.complete();
        final pending = hold;
        if (pending != null) await pending.future;
        request.response.statusCode = status;
        if (status == 302) request.response.headers.set('location', '/wrong');
        request.response.write(reply);
        try {
          await request.response.close();
        } on Exception {
          /* Our client may abort its own deadline. */
        }
      });
    });
    tearDown(() async {
      final pending = hold;
      if (pending != null && !pending.isCompleted) pending.complete();
      await endpoint.close(force: true);
    });
    Future<Result<ArkOperation, ArkWalletFailure>> deliver({String? txid}) =>
        client.submit(
          account,
          ArkSubmission.rebroadcastClaim(
            operationId: 'claim',
            expectedTxid: txid ?? 'd' * 64,
          ),
        );
    test('other background mutations never reach native or HTTP', () async {
      await signedClaim();
      await background();
      final opens = native.opens;
      final children = child.calls;
      for (final submission in [
        ArkSubmission.confirmQuote(quoteId: 'old', operationId: 'new'),
        ArkSubmission.boardFunding(operationId: 'board', quoteId: 'old'),
        ArkSubmission.registerBoard(
          operationId: 'board',
          unfinalisedPsbt: 'public',
          keypairIndex: 1,
          expiryHeight: 200,
        ),
      ]) {
        expect(await client.submit(account, submission), isA<Err>());
      }
      expect(await client.create(config), isA<Err>());
      expect(
        await client.receive(account, ArkReceiveRequest.arkAddress()),
        isA<Err>(),
      );
      expect(
        await client.quote(
          account,
          ArkQuoteRequest.board(amount: Sats.fromInt(1000)),
        ),
        isA<Err>(),
      );
      expect(native.opens, opens);
      expect(child.calls, children);
      expect(posts, isEmpty);
    });
    test(
      'attempt failure prevents POST and preserves original evidence',
      () async {
        await signedClaim();
        await background();
        final db = sqlite3.open(path());
        db.execute(
          "CREATE TRIGGER deny_attempt BEFORE INSERT ON state WHEN NEW.key='claim-delivery:claim' BEGIN SELECT RAISE(ABORT,'test'); END",
        );
        try {
          expect(await deliver(), isA<Err>());
          expect(posts, isEmpty);
        } finally {
          db.execute('DROP TRIGGER deny_attempt');
          db.close();
        }
        expect(await deliver(), isA<Ok>());
        expect(posts, ['raw-public']);
      },
    );
    test('result persistence failure after POST retains the committed unknown attempt', () async {
      await signedClaim();
      await background();
      hold = Completer<void>();
      final delivery = deliver();
      await entered.future;
      final db = sqlite3.open(path());
      db.execute(
        "CREATE TRIGGER deny_result BEFORE UPDATE ON operations WHEN NEW.value LIKE '%\"status\":\"pending\"%' BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      final pending = hold;
      if (pending != null) pending.complete();
      try {
        expect(await delivery, isA<Err>());
      } finally {
        db.execute('DROP TRIGGER deny_result');
        db.close();
      }
      final store = ArkStore.open(path(), create: false);
      expect(
        store.operation('claim')?.operation.status,
        ArkOperationStatus.outcomeUnknown,
      );
      expect(store.get('claim-delivery:claim')?['count'], 1);
      expect(
        store.claimAuthority(
          [FakeOpener.firstId],
          'destination',
          Sats.fromInt(1),
        ),
        isNull,
      );
      store.close();
      expect(posts, ['raw-public']);
    });
    for (final condition in [
      'succeeded',
      'conflicted',
      'policy',
      'budget',
      'identity',
      'corrupt',
      'missing',
      'incompatible',
      'provider',
    ]) {
      test('$condition prevents delivery before any POST', () async {
        await signedClaim();
        await background();
        if (condition == 'policy') policy.allowed = false;
        if (condition == 'budget') budget.allowed = false;
        if (condition == 'provider') preflight.primaryUnreachable = true;
        if (condition == 'succeeded' || condition == 'conflicted') {
          final store = ArkStore.open(path(), create: false);
          final op = store.operation('claim');
          if (op != null) {
            store.saveOperation(
              ArkOperation(
                id: op.operation.id,
                kind: op.operation.kind,
                status: ArkOperationStatus.values.byName(condition),
                chainSource: op.operation.chainSource,
                configGeneration: op.operation.configGeneration,
                nativeReference: op.operation.nativeReference,
                actualIds: op.operation.actualIds,
                claimRecovery: op.operation.claimRecovery,
              ),
              op.binding,
            );
          }
          store.close();
        }
        if (condition == 'corrupt' || condition == 'incompatible') {
          final db = sqlite3.open(path());
          if (condition == 'corrupt') {
            db.execute("UPDATE operations SET evidence='{}' WHERE id='claim'");
          } else {
            db.execute('PRAGMA user_version=999');
          }
          db.close();
        }
        if (condition == 'missing') {
          await File(path()).rename('${path()}.removed');
        }
        final result = await deliver(
          txid: condition == 'identity' ? 'e' * 64 : null,
        );
        expect(
          result,
          condition == 'succeeded' || condition == 'conflicted'
              ? isA<Ok>()
              : isA<Err>(),
        );
        expect(posts, isEmpty);
      });
    }
    for (final stage in ['verifier', 'preflight']) {
      test('budget revoked during $stage await prevents later POST', () async {
        await signedClaim();
        await background();
        if (stage == 'verifier') {
          await background(
            check: _RevokingVerifier(verifier, () => budget.allowed = false),
          );
        } else {
          preflight.beforeSelect = () async {
            await Future<void>.delayed(Duration.zero);
            budget.allowed = false;
          };
        }
        expect(await deliver(), isA<Err>());
        expect(posts, isEmpty);
      });
    }
    for (final failure in [
      'wrong',
      'oversize',
      'error',
      'redirect',
      'deadline',
    ]) {
      test(
        '$failure remains unknown and a later scheduled call reuses bytes',
        () async {
          await signedClaim();
          await background(deadline: const Duration(milliseconds: 200));
          if (failure == 'wrong') reply = 'e' * 64;
          if (failure == 'oversize') reply = 'd' * 1000;
          if (failure == 'error') {
            status = 500;
            reply = 'already known';
          }
          if (failure == 'redirect') status = 302;
          if (failure == 'deadline') hold = Completer<void>();
          expect(await deliver(), isA<Err>());
          final store = ArkStore.open(path(), create: false);
          expect(
            store.operation('claim')?.operation.status,
            ArkOperationStatus.outcomeUnknown,
          );
          expect(store.operation('claim')?.evidence?['raw'], 'raw-public');
          store.close();
          final pending = hold;
          if (pending != null) pending.complete();
          hold = null;
          status = 200;
          reply = 'd' * 64;
          expect(await deliver(), isA<Ok>());
          expect(posts, ['raw-public', 'raw-public']);
          expect(
            preflight.requiredSources.every(
              (source) => source == config.primaryEsploraUrl,
            ),
            isTrue,
          );
        },
      );
    }
    test(
      'writer excludes parallel delivery and close drains held transport',
      () async {
        await signedClaim();
        await background();
        hold = Completer<void>();
        final first = deliver();
        await entered.future;
        expect(await deliver(), isA<Err>());
        var closed = false;
        final closing = client.close().then((_) => closed = true);
        await Future<void>.delayed(Duration.zero);
        expect(closed, isFalse);
        final pending = hold;
        if (pending != null) pending.complete();
        expect(await first, isA<Ok>());
        await closing;
        expect(closed, isTrue);
        expect(posts.length, 1);
      },
    );
    test('background delivers saved bytes after quote expiry with no child or native opening', () async {
      await signedClaim();
      final opens = native.opens;
      final children = child.calls;
      native.exists = false;
      child.failOnce = true;
      await background();
      clock = clock.add(const Duration(days: 1));
      final result = await client.submit(
        account,
        ArkSubmission.rebroadcastClaim(
          operationId: 'claim',
          expectedTxid: 'd' * 64,
        ),
      );
      expect(result, isA<Ok>());
      expect(
        (result as Ok<ArkOperation, ArkWalletFailure>).value.status,
        ArkOperationStatus.pending,
      );
      expect(posts, ['raw-public']);
      expect(native.opens, opens);
      expect(child.calls, children);
      final store = ArkStore.open(path(), create: false);
      expect(
        store.claimAuthority(
          [FakeOpener.firstId],
          'destination',
          Sats.fromInt(1),
        ),
        isNull,
      );
      expect(store.operation('claim')?.evidence?['raw'], 'raw-public');
      store.close();
    });
  });
  for (final missing in [false, true]) {
    test(
      'wrong or missing actual native input amount refuses before debit missing=$missing',
      () async {
        final wallet = _SubsetWallet()
          ..omitFirst = missing
          ..firstAmount = 9999;
        final adapter = BarkNativeSession(
          wallet,
          _SubsetOnchain(),
          _SubsetStages(),
          config,
        );
        native.claimPreparer = adapter.prepareClaim;
        await signedClaim(succeeds: false);
        expect(native.broadcasts, 0);
        final store = ArkStore.open(path(), create: false);
        expect(store.operation('claim')?.evidence?['raw'], isNull);
        expect(
          store.claimAuthority(
            [FakeOpener.firstId],
            'destination',
            Sats.fromInt(100),
          ),
          'exit',
        );
        store.close();
      },
    );
  }
  for (final includeSkipped in [false, true]) {
    test(
      'real adapter two available exits and one actual input remains readable skipped=$includeSkipped',
      () async {
        final wallet = _SubsetWallet();
        final adapter = BarkNativeSession(
          wallet,
          _SubsetOnchain(),
          _SubsetStages(),
          config,
        );
        native.claimPreparer = (quote) async {
          final prepared = await adapter.prepareClaim(quote);
          expect(
            prepared.inputAmounts.length,
            2,
            reason: 'actual adapter reports all available claimable amounts',
          );
          expect(prepared.actualIds, [FakeOpener.firstId]);
          return prepared;
        };
        await signedClaim(
          selected: includeSkipped
              ? [FakeOpener.firstId, FakeOpener.secondId]
              : null,
        );
        final result = await client.read(account);
        expect(result, isA<Ok>());
        final snapshot = (result as Ok<ArkSnapshot, ArkWalletFailure>).value;
        final operation = snapshot.operations.singleWhere(
          (op) => op.id == 'claim',
        );
        expect(operation.claimRecovery?.net, Sats.fromInt(9990));
        expect(
          operation.skippedIds,
          includeSkipped ? [FakeOpener.secondId] : isEmpty,
        );
        final store = ArkStore.open(path(), create: false);
        expect(store.operation('claim')?.evidence?['inputAmounts'], {
          FakeOpener.firstId: '10000',
        });
        if (includeSkipped) {
          expect(
            store.claimAuthority(
              [FakeOpener.secondId],
              'destination',
              Sats.fromInt(90),
            ),
            'exit',
          );
        }
        store.close();
        expect(wallet.drainCalls, 1);
        expect(native.broadcasts, 1);
      },
    );
  }
  test(
    'projection rechecks saved facts instead of trusting a cached summary',
    () async {
      await signedClaim();
      verifier.wrongInputs = true;
      expect(await client.read(account), isA<Err>());
      expect(native.broadcasts, 1);
    },
  );
  test(
    'projection refuses a persisted summary inconsistent with signed amounts',
    () async {
      await signedClaim();
      final db = sqlite3.open(path());
      final row = db
          .select("SELECT value FROM operations WHERE id='claim'")
          .single;
      final value = jsonDecode(row['value'] as String) as Map<String, dynamic>;
      (value['claimRecovery'] as Map<String, dynamic>)['net'] = '1';
      db.execute("UPDATE operations SET value=? WHERE id='claim'", [
        jsonEncode(value),
      ]);
      db.close();
      expect(await client.read(account), isA<Err>());
    },
  );
  test('committed signed evidence cannot be overwritten through status persistence', () async {
    await signedClaim();
    final store = ArkStore.open(path(), create: false);
    final record = store.operation('claim');
    expect(record, isNotNull);
    if (record == null) {
      store.close();
      return;
    }
    final evidence = {...?record.evidence, 'raw': 'different-signed-bytes'};
    expect(
      () => store.saveOperation(
        record.operation,
        record.binding,
        evidence: evidence,
      ),
      throwsFormatException,
    );
    expect(store.operation('claim')?.evidence?['raw'], 'raw-public');
    store.close();
  });
}

// A synthetic non-spendable PSBT exercises the existing FFI extraction codec;
// native wallet handles and host facts remain scripted, not chain/signature proof.
final class _SubsetWallet implements bark.Wallet {
  int drainCalls = 0;
  int firstAmount = 10000;
  bool omitFirst = false;
  @override
  Future<List<bark.ExitVtxo>> listClaimableExits() async => [
    for (final id in [FakeOpener.firstId, FakeOpener.secondId])
      if (!omitFirst || id != FakeOpener.firstId)
        bark.ExitVtxo(
          vtxoId: id,
          amountSats: id == FakeOpener.firstId ? firstAmount : 10000,
          isClaimable: true,
          state: bark.ClaimableExitState(
            tipHeight: 100,
            claimableSince: bark.BlockRef(height: 99, hash: 'c' * 64),
            lastScannedBlock: null,
          ),
        ),
  ];
  @override
  Future<bark.ExitClaimTransaction> drainExits({
    required List<String> vtxoIds,
    required bool drainAll,
    required String address,
    required int? feeRateSatPerVb,
  }) async {
    drainCalls++;
    expect(drainAll, isFalse);
    final tx = _hexBytes(
      '0200000001${'aa' * 32}0000000000ffffffff010627000000000000015100000000',
    );
    final psbt = [
      ..._hexBytes('70736274ff0100'),
      tx.length,
      ...tx,
      ..._hexBytes('0001010a102700000000000001510108030101000000'),
    ];
    return bark.ExitClaimTransaction(
      psbtBase64: base64Encode(psbt),
      feeSats: 10,
      vtxoIds: [FakeOpener.firstId],
      skippedVtxoIds: vtxoIds.where((id) => id != FakeOpener.firstId).toList(),
    );
  }

  List<int> _hexBytes(String hex) => [
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native wallet call');
}

final class _SubsetOnchain implements bark.OnchainWallet {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected onchain call');
}

final class _SubsetStages implements ArkStageRunner {
  @override
  Future<T> run<T>(String name, Future<T> Function() action) => action();
}

final class _RevokingVerifier implements ArkTransactionVerifierPort {
  final ArkTransactionVerifierPort delegate;
  final void Function() revoke;
  _RevokingVerifier(this.delegate, this.revoke);
  @override
  Future<Result<ArkTransactionFacts, ArkWalletFailure>> inspectTransaction({
    required String transactionHex,
    required String signedPsbt,
    required BitcoinNetwork network,
  }) async {
    await Future<void>.delayed(Duration.zero);
    revoke();
    return delegate.inspectTransaction(
      transactionHex: transactionHex,
      signedPsbt: signedPsbt,
      network: network,
    );
  }

  @override
  Future<Result<ArkBoardPsbtFacts, ArkWalletFailure>> inspectBoardPsbt({
    required String unfinalisedPsbt,
    required BitcoinNetwork network,
  }) => delegate.inspectBoardPsbt(
    unfinalisedPsbt: unfinalisedPsbt,
    network: network,
  );
}
