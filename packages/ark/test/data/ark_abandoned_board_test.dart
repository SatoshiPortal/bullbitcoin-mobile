import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:ark/src/data/ark_store.dart';
import 'package:ark/src/data/bark_ark_client.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import '../support/fake_native.dart';

final class Proofs implements ArkBoardAbandonmentPort {
  ArkNeverSignedBoard? proof;
  bool fail = false;
  final requests = <(ArkAccountId, String, String)>[];
  @override
  Future<Result<ArkNeverSignedBoard?, ArkWalletFailure>> readNeverSigned({
    required ArkAccountId account,
    required String operationId,
    required String fundingTxid,
  }) async {
    requests.add((account, operationId, fundingTxid));
    return fail ? const Err(ArkStorageFailure()) : Ok(proof);
  }
}

void main() {
  late Directory temp;
  late FakeOpener native;
  late Proofs proofs;
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
  final clock = DateTime.utc(2026, 11, 17);
  final txid = 'c' * 64;
  final ghost = '${'d' * 64}:0';
  const operationId = 'abandoned-board';
  ArkNeverSignedBoard proof({
    String? fundingTxid,
    String? address,
    int? expiry,
    Sats? net,
  }) => ArkNeverSignedBoard(
    account: account,
    operationId: operationId,
    fundingTxid: fundingTxid ?? txid,
    address: address ?? 'board-address',
    keypairIndex: 7,
    expiryHeight: expiry ?? 1000,
    grossAmount: Sats.fromInt(20000),
    netAmount: net ?? Sats.fromInt(19670),
  );
  BarkArkClient build({ArkExecutionMode mode = ArkExecutionMode.foreground}) =>
      BarkArkClient(
        storagePath: temp.path,
        childProvider: FakeChild(),
        transactionVerifier: FakeVerifier(),
        executionPolicy: FakePolicy(),
        executionMode: mode,
        stageBudget: FakeBudget(),
        opener: native,
        preflight: FakePreflight(),
        clock: () => clock,
        boardAbandonment: proofs,
      );
  setUp(() async {
    temp = Directory.systemTemp.createTempSync('ark-abandoned-board-');
    native = FakeOpener();
    proofs = Proofs()..proof = proof();
    client = build();
    expect(await client.create(config), isA<Ok>());
    final store = ArkStore.open(
      '${ArkStore.accountPath(temp.path, account)}/state.sqlite',
      create: false,
    );
    try {
      final quote = ArkQuote(
        id: 'board-quote',
        account: account,
        generation: 1,
        chainSource: config.primaryEsploraUrl,
        configGeneration: 1,
        kind: ArkOperationKind.board,
        amount: Sats.fromInt(20000),
        fee: Sats.fromInt(330),
        net: Sats.fromInt(19670),
        observedTip: 100,
        validUntil: clock.subtract(const Duration(days: 1)),
      );
      store.saveQuote(quote);
      store.saveOperation(
        ArkOperation(
          id: operationId,
          kind: ArkOperationKind.board,
          status: ArkOperationStatus.pending,
          chainSource: config.primaryEsploraUrl,
          configGeneration: 1,
          nativeReference: txid,
          actualIds: [ghost],
          boardFunding: ArkBoardFundingDetails(
            address: 'board-address',
            keypairIndex: 7,
            expiryHeight: 1000,
          ),
        ),
        quote.id,
      );
    } finally {
      store.close();
    }
    native.inventoryOverride = [
      for (final id in [FakeOpener.firstId, FakeOpener.secondId])
        ArkVtxo(
          id: id,
          amount: Sats.fromInt(10000),
          expiryHeight: 1100,
          state: ArkVtxoState.spendable,
        ),
      ArkVtxo(
        id: ghost,
        amount: Sats.fromInt(19670),
        expiryHeight: 1000,
        state: ArkVtxoState.unknown,
      ),
    ];
    native.pendingBoards = [
      ArkPendingBoard(
        vtxoId: ghost,
        fundingTxid: txid,
        amount: Sats.fromInt(19670),
        expiryHeight: 1000,
      ),
    ];
    native.pendingAmount = Sats.fromInt(19670);
    native.pendingBoardBalance = Sats.fromInt(19670);
  });
  tearDown(() async {
    await client.close();
    temp.deleteSync(recursive: true);
  });
  Future<ArkSnapshot> synchronize() async {
    final result = await client.synchronize(account, renew: false);
    expect(result, isA<Ok>(), reason: '$result');
    return (result as Ok<ArkPassOutcome, ArkWalletFailure>).value.snapshot;
  }

  test('exact never-signed Board proof removes only the unknown freshness barrier and pending balance', () async {
    final snapshot = await synchronize();
    expect(snapshot.stale, false);
    expect(snapshot.vtxoInventoryComplete, true);
    expect(
      snapshot.vtxos.singleWhere((v) => v.id == ghost).state.name,
      'abandonedBoard',
    );
    expect(
      snapshot.vtxos.singleWhere((v) => v.id == ghost).eligibleAt(100),
      false,
    );
    expect(snapshot.pending, Sats.zero);
    expect(snapshot.spendable, Sats.fromInt(20000));
    expect(snapshot.pendingBoards.single.fundingTxid, txid);
    expect(snapshot.pendingBoardCount, 1);
    expect(snapshot.operations.single.id, operationId);
    expect(proofs.requests.single, (account, operationId, txid));
    expect(native.executes, 0);
    expect(native.broadcasts, 0);
  });
  for (final mismatch in [
    'funding',
    'address',
    'expiry',
    'net',
    'missing',
    'failure',
  ]) {
    test(
      'missing or mismatched $mismatch proof leaves unknown and pending protected',
      () async {
        proofs.proof = switch (mismatch) {
          'funding' => proof(fundingTxid: 'e' * 64),
          'address' => proof(address: 'another-address'),
          'expiry' => proof(expiry: 999),
          'net' => proof(net: Sats.fromInt(19669)),
          'missing' => null,
          _ => proof(),
        };
        proofs.fail = mismatch == 'failure';
        final snapshot = await synchronize();
        expect(snapshot.stale, true);
        expect(
          snapshot.vtxos.singleWhere((v) => v.id == ghost).state,
          ArkVtxoState.unknown,
        );
        expect(snapshot.pending, Sats.fromInt(19670));
        expect(snapshot.operations.single.id, operationId);
        expect(native.executes, 0);
      },
    );
  }
  test('unrelated unknown still makes inventory stale after exact Board classification', () async {
    native.inventoryOverride = [
      ...?native.inventoryOverride,
      ArkVtxo(
        id: 'unrelated',
        amount: Sats.fromInt(123),
        expiryHeight: 1100,
        state: ArkVtxoState.unknown,
      ),
    ];
    final snapshot = await synchronize();
    expect(snapshot.stale, true);
    expect(snapshot.vtxoInventoryComplete, false);
    expect(
      snapshot.vtxos.singleWhere((v) => v.id == ghost).state.name,
      'abandonedBoard',
    );
    expect(
      snapshot.vtxos.singleWhere((v) => v.id == 'unrelated').state,
      ArkVtxoState.unknown,
    );
  });
  test('missing native ghost is classified from retained evidence across restart without subtracting Lightning', () async {
    proofs.proof = null;
    expect((await synchronize()).stale, true);
    proofs.proof = proof();
    native.inventoryOverride = native.inventoryOverride
        ?.where((v) => v.id != ghost)
        .toList();
    native.pendingAmount = Sats.fromInt(777);
    native.pendingBoardBalance = Sats.zero;
    final snapshot = await synchronize();
    expect(snapshot.stale, false);
    expect(snapshot.pending, Sats.fromInt(777));
    expect(
      snapshot.vtxos.singleWhere((v) => v.id == ghost).state.name,
      'abandonedBoard',
    );
    await client.close();
    client = build();
    final read = await client.read(account);
    expect(read, isA<Ok<ArkSnapshot, ArkWalletFailure>>());
    expect(
      (read as Ok<ArkSnapshot, ArkWalletFailure>).value.pendingBoardBalance,
      Sats.zero,
    );
    final next = await synchronize();
    expect(next.stale, false);
    expect(next.pending, Sats.fromInt(777));
    expect(next.pendingBoards.single.fundingTxid, txid);
    proofs.fail = true;
    expect((await synchronize()).stale, true);
  });
  test(
    'zero native Board balance never subtracts another pending component',
    () async {
      native.pendingAmount = Sats.fromInt(777);
      native.pendingBoardBalance = Sats.zero;
      final snapshot = await synchronize();
      expect(snapshot.stale, false);
      expect(snapshot.pending, Sats.fromInt(777));
      expect(snapshot.pendingBoardBalance, Sats.zero);
    },
  );
  test(
    'ambiguous or absent native Board linkage never accepts host proof',
    () async {
      native.pendingBoards = [];
      final snapshot = await synchronize();
      expect(snapshot.stale, true);
      expect(proofs.requests, isEmpty);
      expect(snapshot.pending, Sats.fromInt(19670));
    },
  );
  test(
    'duplicate native linkage fails closed before the proof query',
    () async {
      native.pendingBoards = [...native.pendingBoards, ...native.pendingBoards];
      expect((await synchronize()).stale, true);
      expect(proofs.requests, isEmpty);
    },
  );
  test(
    'unknown Board balance refuses to subtract from an aggregate balance',
    () async {
      native.pendingBoardBalance = null;
      expect((await synchronize()).stale, true);
    },
  );
  test('other native staleness and stage failures are not cleared by a Board proof', () async {
    native.observationStale = true;
    expect((await synchronize()).stale, true);
    native.observationStale = false;
    native.failingStage = 'lightning';
    expect((await synchronize()).stale, true);
  });
  test('a real payment quote excludes the abandoned Board and still refuses without its proof', () async {
    final request = ArkQuoteRequest.payment(
      destination: ArkPaymentDestination(
        kind: ArkDestinationKind.ark,
        value: 'recipient',
      ),
      amount: Sats.fromInt(1000),
    );
    final result = await client.quote(account, request);
    expect(result, isA<Ok<ArkQuote, ArkWalletFailure>>());
    final quoted = (result as Ok<ArkQuote, ArkWalletFailure>).value;
    expect(quoted.selectedIds, isNot(contains(ghost)));
    expect(native.executes, 0);
    proofs.proof = null;
    expect(
      await client.quote(account, request),
      isA<Err<ArkQuote, ArkWalletFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ArkRecoveryRequiredFailure>(),
      ),
    );
  });
  test('existing-only background sync accepts the same exact closure proof without new native creation', () async {
    await client.close();
    client = build(mode: ArkExecutionMode.backgroundExisting);
    final creates = native.creates;
    expect((await synchronize()).stale, false);
    expect(native.creates, creates);
    expect(native.executes, 0);
  });
  test('duplicate VTXO identity is not an exact Board observation', () async {
    native.inventoryOverride = [
      ...?native.inventoryOverride,
      (native.inventoryOverride ?? []).last,
    ];
    expect((await synchronize()).stale, true);
    expect(proofs.requests, isEmpty);
  });
}
