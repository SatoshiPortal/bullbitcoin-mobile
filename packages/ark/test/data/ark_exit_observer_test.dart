import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:ark/src/data/ark_store.dart';
import 'package:ark/src/data/ark_writer_lock.dart';
import 'package:ark/src/data/bark_ark_client.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import '../support/fake_native.dart';

final class Observer implements ArkExitObserverPort {
  final Future<void> Function(ArkPassOutcome)? onObserve;
  final Future<void> Function(ArkAccountId, ArkOperation)? onClaim;

  Observer({this.onObserve, this.onClaim});

  @override
  Future<void> observe(ArkPassOutcome outcome) async =>
      onObserve?.call(outcome);

  @override
  Future<void> claimAdmitted(ArkAccountId account, ArkOperation claim) async =>
      onClaim?.call(account, claim);
}

void main() {
  late Directory directory;
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

  BarkArkClient build(ArkExecutionMode mode, {ArkExitObserverPort? observer}) =>
      BarkArkClient(
        storagePath: directory.path,
        childProvider: FakeChild(),
        transactionVerifier: FakeVerifier(),
        executionPolicy: FakePolicy(),
        executionMode: mode,
        stageBudget: FakeBudget(),
        opener: native,
        preflight: FakePreflight(),
        exitObserver: observer,
      );

  setUp(() {
    directory = Directory.systemTemp.createTempSync('ark-exit-observer-');
    native = FakeOpener();
    client = build(ArkExecutionMode.foreground);
  });

  tearDown(() async {
    await client.close();
    directory.deleteSync(recursive: true);
  });

  test(
    'background observation runs while the account writer is held',
    () async {
      expect(await client.create(config), isA<Ok>());
      await client.close();
      var observed = 0;
      client = build(
        ArkExecutionMode.backgroundExisting,
        observer: Observer(
          onObserve: (outcome) async {
            observed++;
            expect(outcome.snapshot.account, account);
            final path = ArkStore.accountPath(directory.path, account);
            expect(
              ArkWriterLock.acquire('$path/writer.sqlite', existingOnly: true),
              isA<Err>(),
            );
          },
        ),
      );
      expect(await client.synchronize(account, renew: false), isA<Ok>());
      expect(observed, 1);
    },
  );

  test('claim observer failure does not change an admitted claim', () async {
    await client.close();
    var observed = 0;
    client = build(
      ArkExecutionMode.foreground,
      observer: Observer(
        onClaim: (owner, claim) async {
          observed++;
          expect(owner, account);
          expect(claim.kind, ArkOperationKind.claim);
          expect(claim.status, ArkOperationStatus.admitted);
          final path = ArkStore.accountPath(directory.path, account);
          expect(
            ArkWriterLock.acquire('$path/writer.sqlite', existingOnly: true),
            isA<Err>(),
          );
          throw Exception('offline');
        },
      ),
    );
    expect(await client.create(config), isA<Ok>());
    final quoted = await client.quote(
      account,
      ArkQuoteRequest.emergencyExit(
        ids: [FakeOpener.firstId],
        destination: 'destination',
        feeRate: FeeRate(1),
        maxClaimFee: Sats.fromInt(100),
      ),
    );
    final quote = (quoted as Ok<ArkQuote, ArkWalletFailure>).value;
    expect(
      await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: quote.id, operationId: 'exit'),
      ),
      isA<Ok>(),
    );
    native.exitDetails = [
      ArkExit(
        id: FakeOpener.firstId,
        amount: Sats.fromInt(10000),
        status: ArkExitStatus.claimable,
      ),
    ];
    expect(await client.synchronize(account, renew: false), isA<Ok>());
    expect(await client.claimAuthorized(account), isA<Ok>());
    expect(native.broadcasts, 1);
    expect(observed, 1);
  });
}
