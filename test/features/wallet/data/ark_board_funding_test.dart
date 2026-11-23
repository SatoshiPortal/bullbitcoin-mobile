import 'dart:async';
import 'dart:convert';

import 'package:ark/ark.dart';
import 'package:fees/fees.dart';
import 'package:bb_mobile/features/wallet/data/ark_board_funding.dart';
import 'package:bb_mobile/features/wallet/data/foreground_wallet_sync.dart';
import 'package:bb_mobile/features/wallet/data/sqlite_ark_funding_reservations.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/public/ark_funding_setup.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

import 'ark_funding_test_fixture.dart';

class _Metadata extends Mock implements WalletRegistrations {}

class _Client extends Mock implements ArkClient {}

class _Fees extends Mock implements Fees {}

class _Custody extends Mock implements ParentCustodyAdmissionPort {}

class _Catalog extends Mock implements WalletCatalogPort {}

class _Reserved extends Mock implements ReservedAddressPort {}

class _Freezes extends Mock implements FreezeStorePort {}

class _Connections extends Mock implements WalletConnectionPort {}

void main() {
  final account = ArkAccountId(
    parent: Fingerprint('00112233'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'public-server',
  );
  late FundingFixture fixture;
  late _Client client;
  late _Metadata metadata;
  late FakeSecureStoragePlatform keystore;
  late WalletNativeRuntime runtime;
  late ForegroundWalletSync sourceSync;
  late WalletArkBoardFunding actor;
  late Secrets secrets;
  late _Fees fees;
  late _Custody custody;
  Future<String> Function(ArkAccountId) selectSource = (_) async =>
      fundingWalletId;

  WalletArkBoardFunding createActor() => WalletArkBoardFunding(
    client: client,
    runtime: runtime,
    authority: fixture.store,
    metadata: metadata,
    sourceSync: sourceSync,
    secrets: secrets,
    fees: fees,
    custody: custody,
    sourceWalletId: (a) => selectSource(a),
  );
  ArkAccountConfig config(ArkAccountId id) => ArkAccountConfig(
    id: id,
    arkUrl: Uri.parse('http://server.invalid'),
    primaryEsploraUrl: Uri.parse('http://chain.invalid'),
  );

  setUp(() {
    fixture = FundingFixture();
    client = _Client();
    metadata = _Metadata();
    fees = _Fees();
    custody = _Custody();
    keystore = FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => fixture.directory.path);
    final connections = _Connections();
    final engine = ElectrumSync(
      connections: connections,
      documentsDirectory: () async => fixture.directory.path,
      readRevision: (_) async => const Err(SyncNotFoundFailure()),
    );
    runtime = WalletNativeRuntime.open(
      catalog: _Catalog(),
      reserved: _Reserved(),
      inputReservations: fixture.store,
      fundingReservations: fixture.store,
      deleteCatalogEntry: (key) async {
        await metadata.delete(key.id);
        return const Ok(null);
      },
      sync: engine,
      documentsDirectory: () async => fixture.directory.path,
      freezes: _Freezes(),
      connections: connections,
    );
    sourceSync = ForegroundWalletSync(engine, native: runtime);
    selectSource = (_) async => fundingWalletId;
    when(() => metadata.fetch(any())).thenAnswer((_) async => null);
    actor = createActor();
  });
  tearDown(() async {
    await actor.close();
    await runtime.close();
    fixture.close();
  });

  Future<(ArkFundingBinding, String)> review({DateTime? validUntil}) async {
    final context = jsonEncode({
      'version': 1,
      'account': account.canonical,
      'quoteId': 'public-quote',
      'amount': '100000',
      'arkFee': '330',
      'net': '99670',
      'fastSatPerKwu': 500,
      'validUntil':
          (validUntil ?? DateTime.now().toUtc().add(const Duration(minutes: 5)))
              .toIso8601String(),
      'chainSource': 'http://chain.invalid',
      'configGeneration': 1,
      'arkUrl': 'http://server.invalid',
      'primary': 'http://chain.invalid',
      'fallback': null,
    });
    final binding = await fixture.reserve(
      'operation',
      context: context,
      account: account.canonical,
    );
    final facts = sourceOk(inspectBitcoinPsbt(publicFundingPsbt));
    final address = sourceOk(
      bitcoinScriptAddress(
        facts.outputs.single.scriptPubkey,
        BitcoinNetwork.regtest,
      ),
    );
    final payload = jsonEncode({
      'request': context,
      'address': address,
      'keypairIndex': 7,
      'expiryHeight': 10000,
      'minerFee': facts.feeSat,
    });
    sourceOk(await fixture.store.saveBoardReview('operation', payload));
    return (
      binding,
      sha256.convert(utf8.encode('$publicFundingPsbt\n$payload')).toString(),
    );
  }

  test(
    'transfer refuses a changed source before any native or metadata call',
    () async {
      final result = await actor.prepareFrom(
        config(account),
        Sats.fromInt(100000),
        sourceWalletId: 'another-wallet',
      );
      expect(result, isA<Err<ArkBoardPreparation, ArkFailure>>());
      verifyZeroInteractions(client);
      verifyZeroInteractions(metadata);
      verifyZeroInteractions(fees);
      verifyZeroInteractions(custody);
    },
  );

  test(
    'mainnet refuses before source selection, Secrets or any Ark native call',
    () async {
      int selections = 0;
      selectSource = (_) async {
        selections++;
        return fundingWalletId;
      };
      final main = ArkAccountId(
        parent: account.parent,
        network: BitcoinNetwork.mainnet,
        serverIdentity: 'public-server',
      );
      // Mainnet configuration requires HTTPS even though no endpoint is called.
      final mainConfig = ArkAccountConfig(
        id: main,
        arkUrl: Uri.parse('https://server.invalid'),
        primaryEsploraUrl: Uri.parse('https://chain.invalid'),
      );
      expect(
        await actor.prepare(mainConfig, Sats.fromInt(20000)),
        isA<Err<ArkBoardPreparation, ArkFailure>>().having(
          (result) => result.failure,
          'actor network refusal',
          isA<ArkInvalidRequestFailure>(),
        ),
      );
      expect(selections, 0);
      expect(keystore.reads, 0);
      verifyZeroInteractions(client);
    },
  );
  test('an unresolved original account operation returns its identity, no reprepare', () async {
    await fixture.reserve('original', account: account.canonical);
    final result = await actor.prepare(config(account), Sats.fromInt(20000));
    expect(
      result,
      isA<Err<ArkBoardPreparation, ArkFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ArkSubmissionUncertainFailure>().having(
          (f) => f.operationId,
          'operation',
          'original',
        ),
      ),
    );
    expect(keystore.reads, 0);
    expect(
      sourceOk(await fixture.store.pendingForAccount(account.canonical)),
      'original',
    );
  });
  test('mismatched review token cannot reach metadata or Secrets', () async {
    await review();
    expect(
      await actor.confirm(account, 'operation', 'not-the-durable-binding'),
      isA<Err<ArkOperation, ArkFailure>>(),
    );
    verifyNever(() => metadata.fetch(any()));
    expect(keystore.reads, 0);
    expect(
      sourceOk(await fixture.store.readBoardReview('operation')).phase,
      'prepared',
    );
  });
  test('cross-account review cannot authorize signing or disclose a ready preparation', () async {
    final data = await review();
    final other = ArkAccountId(
      parent: Fingerprint('ffeeddcc'),
      network: BitcoinNetwork.regtest,
      serverIdentity: 'public-server',
    );
    expect(await actor.confirm(other, 'operation', data.$2), isA<Err>());
    expect(await actor.readPrepared(other, 'operation'), isA<Err>());
    verifyNever(() => metadata.fetch(any()));
    expect(keystore.reads, 0);
  });
  test(
    'signing seal with no saved signature is uncertain, never reviewable again',
    () async {
      final data = await review();
      sourceOk(
        await fixture.store.admitBoardSigning(
          expected: data.$1,
          admittedRevision: fundingStamp,
        ),
      );
      for (final result in [
        await actor.readPrepared(account, 'operation'),
        await actor.confirm(account, 'operation', data.$2),
      ]) {
        expect(
          result,
          isA<Err>().having(
            (e) => e.failure,
            'failure',
            isA<ArkSubmissionUncertainFailure>(),
          ),
        );
      }
      expect(keystore.reads, 0);
      verifyNever(() => metadata.fetch(any()));
      expect(
        sourceOk(await fixture.store.readBoardReview('operation')).signedPsbt,
        isNull,
      );
    },
  );
  for (final phase in ['signed', 'broadcasting']) {
    test(
      '$phase journal never reissues a review or reaches another signer',
      () async {
        final data = await review();
        sourceOk(
          await fixture.store.admitBoardSigning(
            expected: data.$1,
            admittedRevision: fundingStamp,
          ),
        );
        final signed = structuralFinalWitness();
        final facts = sourceOk(inspectBitcoinPsbt(signed));
        expect(facts.finalTransaction, isNotNull);
        expect(facts.unsignedTxid, data.$1.unsignedTxid);
        sourceOk(await fixture.store.recordSigned('operation', signed));
        sourceOk(
          await fixture.store.advanceBoardDelivery(
            'operation',
            expectedPhase: 'signing',
            nextPhase: 'signed',
          ),
        );
        if (phase == 'broadcasting') {
          sourceOk(
            await fixture.store.advanceBoardDelivery(
              'operation',
              expectedPhase: 'signed',
              nextPhase: 'broadcasting',
            ),
          );
        }
        for (final result in [
          await actor.readPrepared(account, 'operation'),
          await actor.confirm(account, 'operation', data.$2),
        ]) {
          expect(
            result,
            isA<Err>().having(
              (e) => e.failure,
              'original operation uncertainty',
              isA<ArkSubmissionUncertainFailure>().having(
                (f) => f.operationId,
                'operation',
                'operation',
              ),
            ),
          );
        }
        expect(keystore.reads, 0);
        verifyNever(() => metadata.fetch(any()));
        expect(
          sourceOk(await fixture.store.readBoardReview('operation')).phase,
          phase,
        );
      },
    );
  }
  test(
    'an expired original review refuses before any provider or signer stage',
    () async {
      final data = await review(
        validUntil: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      );
      when(() => metadata.fetch(fundingWalletId))
          .thenAnswer((_) async => fundingMetadata);
      expect(
        await actor.confirm(account, 'operation', data.$2),
        isA<Err>().having(
          (e) => e.failure,
          'expired',
          isA<ArkReviewExpiredFailure>(),
        ),
      );
      expect(keystore.reads, 0);
      expect(
        sourceOk(await fixture.store.readBoardReview('operation')).phase,
        'prepared',
      );
    },
  );
  for (final minimum in [20000, 54321]) {
    test('native Board minimum $minimum survives the host boundary', () async {
      final data = await review();
      when(() => metadata.fetch(fundingWalletId))
          .thenAnswer((_) async => fundingMetadata);
      // The public confirm path exercises the same native-result mapper as
      // prepare. Refusal precedes signing, so no native source wallet is opened.
      when(() => client.synchronize(account, renew: false)).thenAnswer(
        (_) async =>
            Err(ArkValidationFailure.belowMinimum(Sats.fromInt(minimum))),
      );
      expect(
        await actor.confirm(account, 'operation', data.$2),
        isA<Err<ArkOperation, ArkFailure>>().having(
          (result) => result.failure,
          'typed native minimum',
          isA<ArkBoardBelowMinimumFailure>().having(
            (failure) => failure.minimum,
            'server minimum',
            Sats.fromInt(minimum),
          ),
        ),
      );
      verify(() => client.synchronize(account, renew: false)).called(1);
      expect(keystore.reads, 0);
      expect(
        sourceOk(await fixture.store.readBoardReview('operation')).phase,
        'prepared',
      );
    });
  }
  test('legacy below-minimum failure never invents a minimum', () async {
    final data = await review();
    when(() => metadata.fetch(fundingWalletId))
        .thenAnswer((_) async => fundingMetadata);
    when(() => client.synchronize(account, renew: false)).thenAnswer(
      (_) async =>
          const Err(ArkValidationFailure(ArkFailureReason.belowMinimum)),
    );
    expect(
      await actor.confirm(account, 'operation', data.$2),
      isA<Err<ArkOperation, ArkFailure>>().having(
        (result) => result.failure,
        'missing native minimum',
        isA<ArkServiceUnavailableFailure>(),
      ),
    );
    expect(keystore.reads, 0);
  });
  test(
    'changed source parent refuses without using the old reviewed key',
    () async {
      final data = await review();
      when(() => metadata.fetch(fundingWalletId)).thenAnswer(
        (_) async => fundingMetadata.copyWith(masterFingerprint: 'ffeeddcc'),
      );
      expect(await actor.confirm(account, 'operation', data.$2), isA<Err>());
      expect(keystore.reads, 0);
    },
  );
  test(
    'close drains an admitted source selection and then refuses new work',
    () async {
      final waiting = Completer<String>(), entered = Completer<void>();
      selectSource = (_) {
        entered.complete();
        return waiting.future;
      };
      final preparing = actor.prepare(config(account), Sats.fromInt(20000));
      await entered.future;
      bool closed = false;
      final closing = actor.close().then((_) {
        closed = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      waiting.complete('missing');
      expect(await preparing, isA<Err>());
      await closing;
      expect(closed, isTrue);
      expect(
        await actor.prepare(config(account), Sats.fromInt(20000)),
        isA<Err>(),
      );
      expect(keystore.reads, 0);
    },
  );
  test(
    'wallet setup refuses an authority absent from the native source runtime',
    () async {
      final connections = _Connections();
      final engine = ElectrumSync(
        connections: connections,
        documentsDirectory: () async => fixture.directory.path,
        readRevision: (_) async => const Err(SyncNotFoundFailure()),
      );
      final unconfigured = WalletNativeRuntime.open(
        catalog: _Catalog(),
        reserved: _Reserved(),
        inputReservations: fixture.store,
        deleteCatalogEntry: (key) async {
          await metadata.delete(key.id);
          return const Ok(null);
        },
        sync: engine,
        documentsDirectory: () async => fixture.directory.path,
        freezes: _Freezes(),
        connections: connections,
      );
      final factory = WalletArkFundingFactory(
        authority: fixture.store,
        runtime: unconfigured,
        metadata: metadata,
        sourceSync: sourceSync,
        secrets: secrets,
        fees: fees,
        custody: custody,
      );
      try {
        expect(
          () => factory.bindRealClient(client, (_) async => fundingWalletId),
          throwsStateError,
        );
        expect(keystore.reads, 0);
      } finally {
        await factory.close();
        await unconfigured.close();
      }
    },
  );
  test('wallet setup binds the same real public client once and owns no second client', () async {
    final factory = WalletArkFundingFactory(
      authority: fixture.store,
      runtime: runtime,
      metadata: metadata,
      sourceSync: sourceSync,
      secrets: secrets,
      fees: fees,
      custody: custody,
    );
    expect(
      factory.bindRealClient(client, (_) async => fundingWalletId),
      isA<ArkBoardFundingPort>(),
    );
    expect(
      () => factory.bindRealClient(client, (_) async => fundingWalletId),
      throwsStateError,
    );
    await factory.close();
    expect(
      () => factory.bindRealClient(client, (_) async => fundingWalletId),
      throwsStateError,
    );
    expect(keystore.reads, 0);
  });
}
