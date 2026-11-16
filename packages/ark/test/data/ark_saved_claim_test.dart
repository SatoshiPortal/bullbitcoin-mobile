import 'dart:convert';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_store.dart';
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
  final config = ArkAccountConfig(
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
