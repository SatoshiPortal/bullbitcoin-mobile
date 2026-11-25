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
  test(
    'explicit exit starts only with the same still-confirmed reserve',
    () async {
      native
        ..explicitExitReserve = true
        ..observationStale = true;
      final funding = ArkExitReserveFunding(
        txid: 'f' * 64,
        amount: Sats.fromInt(1000),
      );
      final request = ArkQuoteRequest.emergencyExit(
        ids: [FakeOpener.firstId],
        destination: 'destination',
        maxClaimFee: Sats.fromInt(100),
        reserveFunding: funding,
      );
      expect(await client.quote(account, request), isA<Err>());
      expect(native.importedReserve, isNull);
      native.reserveConfirmed = true;
      native.failReserveImport = true;
      expect(await client.quote(account, request), isA<Err>());
      expect(native.importedReserve, isNull);
      native.failReserveImport = false;
      final quote = ok(
        await client.quote(
          account,
          ArkQuoteRequest.emergencyExit(
            ids: [FakeOpener.firstId],
            destination: 'destination',
            maxClaimFee: Sats.fromInt(100),
          ),
        ),
      );
      expect(native.importedReserve, funding.amount);
      final submit = ArkSubmission.confirmQuote(
        quoteId: quote.id,
        operationId: 'exit',
      );
      native.reserveConfirmed = false;
      expect(await client.submit(account, submit), isA<Err>());
      expect(native.executes, 0);
      native.reserveConfirmed = true;
      expect(
        ok(await client.submit(account, submit)).status,
        ArkOperationStatus.pending,
      );
      expect(
        ok(await client.submit(account, submit)).status,
        ArkOperationStatus.pending,
      );
      expect(native.executes, 1);
    },
  );

  test(
    'submission refuses unexplained disappearance since the reviewed quote',
    () async {
      final quote = ok(
        await client.quote(
          account,
          ArkQuoteRequest.board(amount: Sats.fromInt(20000)),
        ),
      );
      native.missingVtxos = true;
      final result = await client.submit(
        account,
        ArkSubmission.boardFunding(
          quoteId: quote.id,
          operationId: 'missing-inventory',
        ),
      );
      expect(
        native.fundings,
        0,
        reason: 'Missing previously live VTXOs require reconciliation before admitting new funding',
      );
      expect(result, isA<Err<ArkOperation, ArkWalletFailure>>());
    },
  );
  for (final registration in [false, true]) {
    for (final change in ['missing', 'unknown', 'incomplete']) {
      test(
        'submission rejects $change inventory, registration=$registration',
        () async {
          final quote = ok(
            await client.quote(
              account,
              ArkQuoteRequest.board(amount: Sats.fromInt(1000)),
            ),
          );
          if (registration) {
            ok(
              await client.submit(
                account,
                ArkSubmission.boardFunding(
                  quoteId: quote.id,
                  operationId: 'board',
                ),
              ),
            );
          }
          switch (change) {
            case 'missing':
              native.missingVtxos = true;
            case 'unknown':
              native.inventoryOverride = [
                ArkVtxo(
                  id: FakeOpener.firstId,
                  amount: Sats.fromInt(10000),
                  expiryHeight: 1100,
                  state: ArkVtxoState.unknown,
                ),
              ];
            case 'incomplete':
              native.inventoryCompleteness = ArkSectionCompleteness.incomplete;
          }
          final result = await client.submit(
            account,
            registration
                ? ArkSubmission.registerBoard(
                    operationId: 'board',
                    unfinalisedPsbt: 'public',
                    keypairIndex: 4,
                    expiryHeight: 2000,
                  )
                : ArkSubmission.boardFunding(
                    quoteId: quote.id,
                    operationId: 'board',
                  ),
          );
          expect(result, isA<Err<ArkOperation, ArkWalletFailure>>());
          expect(native.fundings, registration ? 1 : 0);
          expect(native.registrations, 0);
        },
      );
    }
  }
  test('unchanged complete inventory admits Board registration', () async {
    final quote = ok(
      await client.quote(
        account,
        ArkQuoteRequest.board(amount: Sats.fromInt(1000)),
      ),
    );
    ok(
      await client.submit(
        account,
        ArkSubmission.boardFunding(
          quoteId: quote.id,
          operationId: 'healthy-board',
        ),
      ),
    );
    ok(
      await client.submit(
        account,
        ArkSubmission.registerBoard(
          operationId: 'healthy-board',
          unfinalisedPsbt: 'public',
          keypairIndex: 4,
          expiryHeight: 2000,
        ),
      ),
    );
    expect(native.fundings, 1);
    expect(native.registrations, 1);
  });

  for (final changedTip in [false, true]) {
    test('live board checks same-height chain changes: $changedTip', () async {
      native
        ..requireBoardServerInfo = false
        ..observationStale = true
        ..inventoryCompleteness = ArkSectionCompleteness.incomplete
        ..liveBoardTipHash = 'a' * 64;
      final quote = ok(
        await client.quote(
          account,
          ArkQuoteRequest.board(amount: Sats.fromInt(1000)),
        ),
      );
      final prepared = ok(
        await client.submit(
          account,
          ArkSubmission.boardFunding(
            quoteId: quote.id,
            operationId: 'live-board',
          ),
        ),
      );
      expect(prepared.boardFunding?.scuttleToken, 'opaque-funding-token');
      if (changedTip) native.liveBoardTipHash = 'b' * 64;
      final registration = await client.submit(
        account,
        ArkSubmission.registerBoard(
          operationId: 'live-board',
          unfinalisedPsbt: 'public',
          keypairIndex: null,
          expiryHeight: 2000,
        ),
      );
      if (changedTip) {
        expect(registration, isA<Err<ArkOperation, ArkWalletFailure>>());
      } else {
        expect(ok(registration).status, ArkOperationStatus.pending);
      }
      expect(native.registrations, changedTip ? 0 : 1);
      expect(ok(await client.read(account)).stale, isTrue);
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
        isA<Err<ArkQuote, ArkWalletFailure>>(),
      );
    });
  }
}
