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
    'failed final observation survives read, restart and server-only refresh',
    () async {
      final issued = ok(
        await client.quote(
          account,
          ArkQuoteRequest.board(amount: Sats.fromInt(20000)),
        ),
      );
      native.failingStage = 'observe';
      expect(
        await client.synchronize(account, renew: false),
        isA<Err<ArkPassOutcome, ArkWalletFailure>>(),
      );
      expect(ok(await client.read(account)).stale, true);
      native.failingStage = null;
      await client.close();
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
      expect(ok(await client.read(account)).stale, true);
      expect(
        await client.submit(
          account,
          ArkSubmission.boardFunding(
            quoteId: issued.id,
            operationId: 'before-recovery',
          ),
        ),
        isA<Err<ArkOperation, ArkWalletFailure>>(),
      );
      expect(native.fundings, 0);
      expect(
        await client.quote(
          account,
          ArkQuoteRequest.board(amount: Sats.fromInt(20000)),
        ),
        isA<Err<ArkQuote, ArkWalletFailure>>(),
      );
      expect(ok(await client.read(account)).stale, true);
      final recovered = ok(await client.synchronize(account, renew: false));
      expect(recovered.snapshot.stale, false);
      final quote = ok(
        await client.quote(
          account,
          ArkQuoteRequest.board(amount: Sats.fromInt(20000)),
        ),
      );
      ok(
        await client.submit(
          account,
          ArkSubmission.boardFunding(
            quoteId: quote.id,
            operationId: 'after-recovery',
          ),
        ),
      );
      expect(native.fundings, 1);
    },
  );
}
