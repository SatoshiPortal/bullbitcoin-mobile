import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:ark/src/data/bark_ark_client.dart';
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
  ArkQuoteRequest request(String kind) => switch (kind) {
    'claim' => ArkQuoteRequest.claim(
      ids: [FakeOpener.firstId],
      destination: 'destination',
      maxFee: Sats.fromInt(100),
    ),
    'progress' => ArkQuoteRequest.exitProgress(feeRate: FeeRate(1)),
    _ => ArkQuoteRequest.emergencyExit(
      ids: [FakeOpener.firstId],
      destination: 'destination',
      feeRate: FeeRate(1),
      maxClaimFee: Sats.fromInt(100),
    ),
  };
  void unknownUnrelated(String kind) {
    native.claimableIds = [FakeOpener.firstId];
    native.exitDetails = [
      ArkExit(
        id: FakeOpener.firstId,
        amount: Sats.fromInt(10000),
        status: ArkExitStatus.claimable,
      ),
    ];
    native.inventoryOverride = [
      ArkVtxo(
        id: FakeOpener.firstId,
        amount: Sats.fromInt(10000),
        expiryHeight: 1100,
        state: kind == 'claim' ? ArkVtxoState.exited : ArkVtxoState.spendable,
      ),
      ArkVtxo(
        id: FakeOpener.secondId,
        amount: Sats.fromInt(10000),
        expiryHeight: 1100,
        state: ArkVtxoState.unknown,
      ),
    ];
  }

  for (final kind in ['emergency', 'progress', 'claim']) {
    test(
      '$kind ignores unrelated inventory staleness without admitting its unknown ids',
      () async {
        unknownUnrelated(kind);
        final reviewed = ok(await client.quote(account, request(kind)));
        expect(reviewed.selectedIds, [FakeOpener.firstId]);
        expect(ok(await client.read(account)).stale, true);
        final result = await client.submit(
          account,
          ArkSubmission.confirmQuote(quoteId: reviewed.id, operationId: kind),
        );
        expect(result, isA<Ok<ArkOperation, ArkWalletFailure>>());
        expect(native.executes, kind == 'claim' ? 0 : 1);
        expect(native.broadcasts, kind == 'claim' ? 1 : 0);
        expect(ok(await client.read(account)).stale, true);
      },
    );
    test('$kind still refuses native staleness', () async {
      unknownUnrelated(kind);
      final reviewed = ok(await client.quote(account, request(kind)));
      native.observationStale = true;
      expect(
        await client.submit(
          account,
          ArkSubmission.confirmQuote(quoteId: reviewed.id, operationId: kind),
        ),
        isA<Err<ArkOperation, ArkWalletFailure>>(),
      );
      expect(native.executes, 0);
      expect(native.preparations, 0);
      expect(native.broadcasts, 0);
    });
  }
  for (final kind in ['board', 'payment']) {
    test(
      '$kind still refuses an unrelated unknown during submission',
      () async {
        final reviewed = ok(
          await client.quote(
            account,
            kind == 'board'
                ? ArkQuoteRequest.board(amount: Sats.fromInt(1000))
                : ArkQuoteRequest.payment(
                    destination: ArkPaymentDestination(
                      kind: ArkDestinationKind.ark,
                      value: 'address',
                    ),
                    amount: Sats.fromInt(1000),
                  ),
          ),
        );
        unknownUnrelated(kind);
        final command = kind == 'board'
            ? ArkSubmission.boardFunding(
                quoteId: reviewed.id,
                operationId: kind,
              )
            : ArkSubmission.confirmQuote(
                quoteId: reviewed.id,
                operationId: kind,
              );
        expect(
          await client.submit(account, command),
          isA<Err<ArkOperation, ArkWalletFailure>>(),
        );
        expect(native.fundings, 0);
        expect(native.executes, 0);
      },
    );
  }
}
