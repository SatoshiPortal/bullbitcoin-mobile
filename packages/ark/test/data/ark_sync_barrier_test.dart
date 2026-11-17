import 'dart:async';
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
  late FakeBudget budget;
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
  final request = ArkQuoteRequest.board(amount: Sats.fromInt(20000));
  final clock = DateTime.utc(2026, 11, 17);
  BarkArkClient build() => BarkArkClient(
    storagePath: temp.path,
    childProvider: FakeChild(),
    transactionVerifier: FakeVerifier(),
    executionPolicy: FakePolicy(),
    executionMode: ArkExecutionMode.foreground,
    stageBudget: budget,
    opener: native,
    preflight: FakePreflight(),
    clock: () => clock,
  );
  T requireOk<T>(Result<T, ArkWalletFailure> result) {
    if (result case Ok(:final value)) return value;
    fail('Expected the fixture operation to succeed');
  }

  Future<ArkSnapshot> snapshot() async => requireOk(await client.read(account));
  setUp(() async {
    temp = Directory.systemTemp.createTempSync('ark-sync-barrier-');
    native = FakeOpener()..requireBoardServerInfo = true;
    budget = FakeBudget();
    client = build();
    requireOk(await client.create(config));
  });
  tearDown(() async {
    await client.close();
    temp.deleteSync(recursive: true);
  });
  Future<void> failOnchain() async {
    native.failingStage = 'onchain';
    final pass = requireOk(await client.synchronize(account, renew: false));
    expect(pass.failedStages, ['onchain']);
    expect(pass.completedStages, isNot(contains(ArkStage.onchain)));
    expect(pass.snapshot.stale, true);
    expect(pass.snapshot.recovery, ArkRecoveryStatus.complete);
    expect(pass.snapshot.vtxoInventoryComplete, true);
    expect(pass.snapshot.tipHeight, 100);
    expect(pass.snapshot.vtxos.map((v) => v.id), [
      FakeOpener.firstId,
      FakeOpener.secondId,
    ]);
  }

  Future<void> refuseQuoteAndSubmission() async {
    final quoted = await client.quote(account, request);
    // Exercise the unsafe continuation before asserting, rather than letting
    // the first quote assertion hide an independently admitted funding call.
    Result<ArkOperation, ArkWalletFailure>? submitted;
    if (quoted case Ok(:final value)) {
      submitted = await client.submit(
        account,
        ArkSubmission.boardFunding(
          operationId: 'must-not-fund',
          quoteId: value.id,
        ),
      );
    }
    expect(quoted, isA<Err<ArkQuote, ArkWalletFailure>>());
    if (submitted != null) {
      expect(submitted, isA<Err<ArkOperation, ArkWalletFailure>>());
    }
    expect(native.fundings, 0);
    expect(native.registrations, 0);
    expect(native.executes, 0);
    expect((await snapshot()).stale, true);
  }

  for (final restart in [false, true]) {
    test(
      'onchain failure survives server-only quote and submit restart=$restart',
      () async {
        await failOnchain();
        native.failingStage = null;
        if (restart) {
          await client.close();
          client = build();
        }
        await refuseQuoteAndSubmission();
      },
    );
  }
  test('direct issued quote cannot bypass failed onchain after deferred observation', () async {
    final issued = requireOk(await client.quote(account, request));
    native.failingStage = 'onchain';
    native.afterStage = (stage) {
      if (stage == 'exits-observe') budget.allowed = false;
    };
    final pass = requireOk(await client.synchronize(account, renew: false));
    expect(pass.failedStages, contains('onchain'));
    expect(pass.failedStages, contains('deferred'));
    expect(pass.snapshot.revision, issued.generation);
    expect(issued.validUntil.isAfter(clock), true);
    expect(pass.snapshot.tipHeight, issued.observedTip);
    expect(pass.snapshot.serverInfo?.publicKey, 'server-key');
    expect(issued.fee, Sats.fromInt(10));
    expect(issued.net, Sats.fromInt(19990));
    expect(pass.snapshot.stale, true);
    budget.allowed = true;
    native.afterStage = null;
    native.failingStage = null;
    final result = await client.submit(
      account,
      ArkSubmission.boardFunding(
        operationId: 'issued-before-failure',
        quoteId: issued.id,
      ),
    );
    expect(result, isA<Err<ArkOperation, ArkWalletFailure>>());
    expect(native.fundings, 0);
    expect(native.registrations, 0);
    expect(native.executes, 0);
    expect((await snapshot()).stale, true);
  });
  test(
    'positive onchain synchronization restores ordinary admission',
    () async {
      await failOnchain();
      native.failingStage = null;
      await refuseQuoteAndSubmission();
      final completed = <String>[];
      native.afterStage = completed.add;
      final pass = requireOk(await client.synchronize(account, renew: false));
      expect(completed, contains('onchain'));
      expect(pass.failedStages, isEmpty);
      expect(pass.snapshot.stale, false);
      final quote = requireOk(await client.quote(account, request));
      final funded = requireOk(
        await client.submit(
          account,
          ArkSubmission.boardFunding(
            operationId: 'after-positive-sync',
            quoteId: quote.id,
          ),
        ),
      );
      expect(funded.status, ArkOperationStatus.prepared);
      expect(native.fundings, 1);
      expect(native.executes, 0);
      expect(native.registrations, 0);
    },
  );
  test(
    'onchain success does not clear another unresolved server failure',
    () async {
      await failOnchain();
      native.failingStage = 'server';
      final pass = requireOk(await client.synchronize(account, renew: false));
      expect(pass.completedStages, contains(ArkStage.onchain));
      expect(pass.failedStages, ['server']);
      expect(pass.snapshot.stale, true);
      native.failingStage = null;
      await refuseQuoteAndSubmission();
      final recovered = requireOk(
        await client.synchronize(account, renew: false),
      );
      expect(recovered.failedStages, isEmpty);
      expect(recovered.snapshot.stale, false);
      expect(
        await client.quote(account, request),
        isA<Ok<ArkQuote, ArkWalletFailure>>(),
      );
      expect(native.fundings, 0);
    },
  );
  test(
    'budget-only deferred opaque exits work recovers after actual execution',
    () async {
      native.afterStage = (stage) {
        if (stage == 'onchain') budget.allowed = false;
      };
      final deferred = requireOk(
        await client.synchronize(account, renew: false),
      );
      expect(deferred.failedStages, ['deferred', 'deferred']);
      expect(deferred.completedStages, isNot(contains(ArkStage.exits)));
      expect(deferred.snapshot.stale, true);
      budget.allowed = true;
      native.afterStage = null;
      await refuseQuoteAndSubmission();
      final actualStages = <String>[];
      native.afterStage = actualStages.add;
      final recovered = requireOk(
        await client.synchronize(account, renew: false),
      );
      expect(actualStages, contains('exits-observe'));
      expect(recovered.failedStages, isEmpty);
      expect(recovered.snapshot.stale, false);
      expect(
        await client.quote(account, request),
        isA<Ok<ArkQuote, ArkWalletFailure>>(),
      );
      expect(native.fundings, 0);
    },
  );
  test(
    'observed opaque exits failure is not resolved by a later void success',
    () async {
      native.failingStage = 'exits-observe';
      final failed = requireOk(await client.synchronize(account, renew: false));
      expect(failed.failedStages, ['exits-observe']);
      expect(failed.snapshot.stale, true);
      native.failingStage = null;
      final actualStages = <String>[];
      native.afterStage = actualStages.add;
      final retry = requireOk(await client.synchronize(account, renew: false));
      expect(actualStages, contains('exits-observe'));
      expect(retry.snapshot.stale, true);
      await refuseQuoteAndSubmission();
    },
  );
  test(
    'failed observation commit rolls back cause clearing across restart',
    () async {
      await failOnchain();
      final previous = await snapshot();
      final ready = Completer<void>();
      final seen = <ArkSnapshot>[];
      final subscription = client.watch(account).listen((result) {
        if (result case Ok(:final value)) {
          seen.add(value);
          if (!ready.isCompleted) ready.complete();
        }
      });
      await ready.future;
      final path = '${ArkStore.accountPath(temp.path, account)}/state.sqlite';
      final database = sqlite3.open(path);
      try {
        database.execute('''
        CREATE TRIGGER refuse_observation BEFORE UPDATE ON state
        WHEN NEW.key='snapshot'
        BEGIN SELECT RAISE(ABORT, 'observation unavailable'); END
      ''');
      } finally {
        database.close();
      }
      native.failingStage = null;
      final result = await client.synchronize(account, renew: false);
      expect(result, isA<Err<ArkPassOutcome, ArkWalletFailure>>());
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(seen, hasLength(1));
      expect(seen.every((s) => s.stale), true);
      final stored = await snapshot();
      expect(stored.revision, previous.revision);
      expect(stored.stale, true);
      final cleanup = sqlite3.open(path);
      try {
        cleanup.execute('DROP TRIGGER refuse_observation');
      } finally {
        cleanup.close();
      }
      await client.close();
      client = build();
      await refuseQuoteAndSubmission();
      final recovered = requireOk(
        await client.synchronize(account, renew: false),
      );
      expect(recovered.snapshot.stale, false);
    },
  );
}
