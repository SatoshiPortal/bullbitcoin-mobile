import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:ark/src/data/ark_store.dart';
import 'package:ark/src/data/bark_ark_client.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../support/fake_native.dart';

void main() {
  late Directory temp;
  late FakeOpener native;
  late FakeVerifier verifier;
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
  T ok<T>(Result<T, ArkWalletFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err() => throw StateError('Expected Ok'),
  };
  String path() => '${ArkStore.accountPath(temp.path, account)}/state.sqlite';
  BarkArkClient build({ArkExecutionMode mode = ArkExecutionMode.foreground}) =>
      BarkArkClient(
        storagePath: temp.path,
        childProvider: FakeChild(),
        transactionVerifier: verifier,
        executionPolicy: FakePolicy(),
        executionMode: mode,
        stageBudget: FakeBudget(),
        opener: native,
        preflight: FakePreflight(),
        clock: () => DateTime.utc(2026, 11, 18),
      );
  T store<T>(T Function(ArkStore) action) {
    final db = ArkStore.open(path(), create: false);
    try {
      return action(db);
    } finally {
      db.close();
    }
  }

  List<Map<String, Object?>> allocations() {
    final db = sqlite3.open(path(), mode: OpenMode.readOnly);
    try {
      return db
          .select('SELECT * FROM claim_allowances ORDER BY authority')
          .map((r) => Map<String, Object?>.from(r))
          .toList();
    } finally {
      db.close();
    }
  }

  Future<ArkQuote> quote({int maximum = 100}) async => ok(
    await client.quote(
      account,
      ArkQuoteRequest.claim(
        ids: [FakeOpener.firstId],
        destination: 'destination',
        maxFee: Sats.fromInt(maximum),
      ),
    ),
  );
  void existing() => store((db) {
    expect(
      db.createClaimAuthority(
        'old',
        [FakeOpener.firstId, FakeOpener.secondId],
        'destination',
        Sats.fromInt(100),
      ),
      true,
    );
  });
  setUp(() async {
    temp = Directory.systemTemp.createTempSync('ark-claim-authority-');
    native = FakeOpener();
    verifier = FakeVerifier();
    client = build();
    ok(await client.create(config));
    // A native exit that was not initiated by this client's operation journal.
    native.claimableIds = [FakeOpener.firstId, FakeOpener.secondId];
    native.exitDetails = [
      for (final id in [FakeOpener.firstId, FakeOpener.secondId])
        ArkExit(
          id: id,
          amount: Sats.fromInt(10000),
          status: ArkExitStatus.claimable,
        ),
    ];
    native.inventoryOverride = [
      for (final id in [FakeOpener.firstId, FakeOpener.secondId])
        ArkVtxo(
          id: id,
          amount: Sats.fromInt(10000),
          expiryHeight: 1100,
          state: ArkVtxoState.exited,
        ),
    ];
  });
  tearDown(() async {
    await client.close();
    temp.deleteSync(recursive: true);
  });

  test('a claim quote and restart do not create an authority', () async {
    final reviewed = await quote();
    expect(allocations(), isEmpty);
    expect(native.preparations, 0);
    expect(native.broadcasts, 0);
    await client.close();
    client = build();
    expect(store((db) => db.quote(reviewed.id)?.destination), 'destination');
    expect(allocations(), isEmpty);
    expect(native.preparations, 0);
  });
  test(
    'confirmed existing-exit claim admits an authority and remains idempotent',
    () async {
      final reviewed = await quote();
      expect(allocations(), isEmpty);
      final command = ArkSubmission.confirmQuote(
        quoteId: reviewed.id,
        operationId: 'claim',
      );
      expect(
        ok(await client.submit(account, command)).status,
        ArkOperationStatus.pending,
      );
      final debited = allocations();
      expect(debited, hasLength(1));
      expect(debited.single['remaining_fee'], '90');
      expect(debited.single['remaining_ids'], '[]');
      expect(native.broadcasts, 1);
      await client.close();
      client = build();
      expect(
        ok(await client.submit(account, command)).status,
        ArkOperationStatus.pending,
      );
      expect(allocations(), debited);
      expect(native.preparations, 1);
      expect(native.broadcasts, 1);
    },
  );
  test(
    'raising the fee authority changes only selected ids at submission',
    () async {
      existing();
      native.claimFee = 150;
      verifier.fee = 150;
      final before = allocations();
      final reviewed = await quote(maximum: 200);
      expect(allocations(), before);
      expect(
        store(
          (db) => db.claimAuthority(
            [FakeOpener.firstId],
            'destination',
            Sats.fromInt(200),
          ),
        ),
        isNull,
      );
      ok(
        await client.submit(
          account,
          ArkSubmission.confirmQuote(
            quoteId: reviewed.id,
            operationId: 'raise',
          ),
        ),
      );
      final old = allocations().singleWhere((row) => row['authority'] == 'old');
      expect(old['remaining_ids'], '["${FakeOpener.secondId}"]');
      expect(old['remaining_fee'], '100');
      expect(old['destination'], 'destination');
      final replaced = allocations().singleWhere(
        (row) => row['authority'] != 'old',
      );
      expect(replaced['remaining_fee'], '50');
      expect(native.broadcasts, 1);
    },
  );
  for (final replacement in [false, true]) {
    test(
      'authority and admission roll back together, replacement=$replacement',
      () async {
        if (replacement) existing();
        final before = allocations();
        final reviewed = await quote(maximum: replacement ? 200 : 100);
        final db = sqlite3.open(path());
        db.execute(
          "CREATE TRIGGER deny_claim BEFORE INSERT ON operations WHEN NEW.id='claim' BEGIN SELECT RAISE(ABORT,'admission interruption'); END",
        );
        try {
          expect(
            await client.submit(
              account,
              ArkSubmission.confirmQuote(
                quoteId: reviewed.id,
                operationId: 'claim',
              ),
            ),
            isA<Err>(),
          );
          expect(allocations(), before);
          expect(store((db) => db.operation('claim')), isNull);
          expect(native.preparations, 0);
          expect(native.broadcasts, 0);
        } finally {
          db.execute('DROP TRIGGER deny_claim');
          db.close();
        }
        ok(
          await client.submit(
            account,
            ArkSubmission.confirmQuote(
              quoteId: reviewed.id,
              operationId: 'claim',
            ),
          ),
        );
        expect(native.broadcasts, 1);
      },
    );
  }
  for (final status in [
    ArkOperationStatus.admitted,
    ArkOperationStatus.outcomeUnknown,
  ]) {
    test('overlapping $status claim refuses authority creation', () async {
      final reviewed = await quote();
      store(
        (db) => db.saveOperation(
          ArkOperation(
            id: 'overlap',
            kind: ArkOperationKind.claim,
            status: status,
            chainSource: config.primaryEsploraUrl,
            configGeneration: 1,
            actualIds: [FakeOpener.firstId],
          ),
          'other-quote',
        ),
      );
      expect(
        await client.submit(
          account,
          ArkSubmission.confirmQuote(
            quoteId: reviewed.id,
            operationId: 'claim',
          ),
        ),
        isA<Err>(),
      );
      expect(allocations(), isEmpty);
      expect(native.preparations, 0);
      expect(native.broadcasts, 0);
    });
  }
  test('background claim paths never create an authority', () async {
    final reviewed = await quote();
    await client.close();
    client = build(mode: ArkExecutionMode.backgroundExisting);
    final opens = native.opens;
    expect(
      await client.quote(
        account,
        ArkQuoteRequest.claim(
          ids: [FakeOpener.firstId],
          destination: 'destination',
          maxFee: Sats.fromInt(100),
        ),
      ),
      isA<Err>(),
    );
    expect(
      await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: reviewed.id, operationId: 'claim'),
      ),
      isA<Err>(),
    );
    expect(native.opens, opens);
    expect(allocations(), isEmpty);
    expect(native.preparations, 0);
  });
  test('lost native exit refuses before authority admission', () async {
    final reviewed = await quote();
    native.claimableIds = [];
    expect(
      await client.submit(
        account,
        ArkSubmission.confirmQuote(quoteId: reviewed.id, operationId: 'claim'),
      ),
      isA<Err>(),
    );
    expect(allocations(), isEmpty);
    expect(native.preparations, 0);
  });
  test(
    'signed overlapping claim retains evidence and refuses a new authority',
    () async {
      final first = await quote();
      ok(
        await client.submit(
          account,
          ArkSubmission.confirmQuote(quoteId: first.id, operationId: 'signed'),
        ),
      );
      final evidence = store((db) => db.operation('signed')?.evidence);
      expect(evidence?['raw'], 'raw-public');
      final before = allocations();
      final next = await quote(maximum: 200);
      expect(
        await client.submit(
          account,
          ArkSubmission.confirmQuote(
            quoteId: next.id,
            operationId: 'overlap-signed',
          ),
        ),
        isA<Err>(),
      );
      expect(allocations(), before);
      expect(store((db) => db.operation('signed')?.evidence), evidence);
      expect(native.preparations, 1);
      expect(native.broadcasts, 1);
    },
  );
}
