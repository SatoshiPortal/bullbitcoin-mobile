import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:ark/src/data/bark_ark_client.dart';
import 'package:ark/src/data/ark_store.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import '../support/fake_native.dart';

void main() {
  late Directory temp;
  late FakeOpener native;
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
  T ok<T>(Result<T, ArkWalletFailure> result) {
    if (result case Ok(:final value)) return value;
    throw StateError('Expected Ok');
  }

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('astra-review-');
    native = FakeOpener()..requireBoardServerInfo = true;
    client = BarkArkClient(
      storagePath: temp.path,
      childProvider: FakeChild(),
      transactionVerifier: FakeVerifier(),
      executionPolicy: FakePolicy(),
      executionMode: ArkExecutionMode.foreground,
      stageBudget: FakeBudget(),
      opener: native,
      preflight: FakePreflight(),
      clock: () => DateTime.utc(2026, 11, 17),
    );
    ok(await client.create(config));
  });
  tearDown(() async {
    await client.close();
    temp.deleteSync(recursive: true);
  });
  Future<ArkOperation> unknown(String kind, {bool both = false}) async {
    final quote = ok(
      await client.quote(
        account,
        kind == 'payment'
            ? ArkQuoteRequest.payment(
                destination: ArkPaymentDestination(
                  kind: ArkDestinationKind.ark,
                  value: 'address',
                ),
                amount: Sats.fromInt(1000),
              )
            : ArkQuoteRequest.renewal(
                ids: [FakeOpener.firstId, if (both) FakeOpener.secondId],
              ),
      ),
    );
    native.failExecute = true;
    final operation = ok(
      await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: quote.id, operationId: 'unknown'),
      ),
    );
    expect(operation.status, ArkOperationStatus.outcomeUnknown);
    native.failExecute = false;
    return operation;
  }

  for (final kind in ['payment', 'renewal']) {
    test(
      'complete same-provider observation settles unconsumed $kind failure',
      () async {
        await unknown(kind);
        final pass = ok(await client.synchronize(account, renew: false));
        expect(pass.snapshot.stale, false);
        expect(
          pass.snapshot.operations.singleWhere((o) => o.id == 'unknown').status,
          ArkOperationStatus.failed,
        );
        expect(
          native.executes,
          1,
          reason: 'reconciliation never replays the operation',
        );
        final snapshot = ok(await client.read(account));
        expect(
          snapshot.operations.singleWhere((o) => o.id == 'unknown').status,
          ArkOperationStatus.failed,
        );
      },
    );
  }
  for (final weakness in ['pending', 'consumed', 'incomplete']) {
    test(
      '$weakness observation preserves unknown operation protection',
      () async {
        await unknown('renewal');
        if (weakness == 'pending') {
          native.inventoryOverride = [
            for (final id in [FakeOpener.firstId, FakeOpener.secondId])
              ArkVtxo(
                id: id,
                amount: Sats.fromInt(10000),
                expiryHeight: 1100,
                state: ArkVtxoState.spendable,
                pendingRound: id == FakeOpener.firstId,
              ),
          ];
        }
        if (weakness == 'consumed') {
          native.movementEvidence = [
            ArkMovement(
              id: 'consumed',
              kind: ArkMovementKind.payment,
              status: ArkMovementStatus.pending,
              amount: Sats.fromInt(1000),
              fee: Sats.zero,
              inputVtxoIds: [FakeOpener.firstId],
            ),
          ];
        }
        if (weakness == 'incomplete') {
          native.inventoryCompleteness = ArkSectionCompleteness.incomplete;
        }
        final pass = ok(await client.synchronize(account, renew: false));
        expect(
          pass.snapshot.operations.singleWhere((o) => o.id == 'unknown').status,
          ArkOperationStatus.outcomeUnknown,
        );
        expect(native.executes, 1);
      },
    );
  }
  test('emergency exit bypasses unknown hold only for selected ids', () async {
    final original = await unknown('renewal', both: true);
    final exitQuote = ok(
      await client.quote(
        account,
        ArkQuoteRequest.emergencyExit(
          ids: [FakeOpener.firstId],
          destination: 'destination',
          feeRate: FeeRate(1),
          maxClaimFee: Sats.fromInt(100),
        ),
      ),
    );
    ok(
      await client.submit(
        account,
        ArkSubmission.confirmQuote(
          quoteId: exitQuote.id,
          operationId: 'protect-first',
        ),
      ),
    );
    expect(native.executes, 2);
    final remainingQuote = ok(
      await client.quote(
        account,
        ArkQuoteRequest.renewal(ids: [FakeOpener.secondId]),
      ),
    );
    expect(
      await client.submit(
        account,
        ArkSubmission.confirmQuote(
          quoteId: remainingQuote.id,
          operationId: 'blocked-second',
        ),
      ),
      isA<Err<ArkOperation, ArkWalletFailure>>(),
    );
    expect(native.executes, 2);
    final operation = ok(await client.read(account)).operations
        .singleWhere((o) => o.id == original.id);
    expect(operation.status, ArkOperationStatus.outcomeUnknown);
    expect(operation.actualIds, original.actualIds);
  });
  test('failed final commit cannot release unknown input holds', () async {
    await unknown('renewal');
    final path = '${ArkStore.accountPath(temp.path, account)}/state.sqlite';
    final db = sqlite3.open(path);
    db.execute(
      "CREATE TRIGGER deny_inventory BEFORE INSERT ON state WHEN NEW.key='inventory-obligations' BEGIN SELECT RAISE(ABORT,'test interruption after settlement'); END",
    );
    try {
      expect(await client.synchronize(account, renew: false), isA<Err>());
      final reopened = ArkStore.open(path, create: false);
      try {
        expect(
          reopened.operation('unknown')?.operation.status,
          ArkOperationStatus.outcomeUnknown,
        );
      } finally {
        reopened.close();
      }
    } finally {
      db.execute('DROP TRIGGER deny_inventory');
      db.close();
    }
    expect(
      ok(await client.synchronize(account, renew: false)).snapshot.operations
          .singleWhere((o) => o.id == 'unknown')
          .status,
      ArkOperationStatus.failed,
    );
    expect(native.executes, 1);
  });
}
