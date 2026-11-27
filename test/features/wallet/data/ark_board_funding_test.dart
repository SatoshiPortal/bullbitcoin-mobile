import 'dart:async';
import 'dart:convert';

import 'package:ark/ark.dart';
import 'package:fees/fees.dart';
import 'package:bull_ark/testing.dart';
import 'package:bull_ark/ark_wallet_setup.dart';
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

class _Metadata extends Mock implements WalletInventory {}

class _Client extends Mock implements ArkClient {}

class _Fees extends Mock implements Fees {}

class _Custody extends Mock implements ParentCustodyAdmissionPort {}

class _Catalog extends Mock implements WalletCatalogPort {}

class _Reserved extends Mock implements ReservedAddressPort {}

class _Freezes extends Mock implements FreezeStorePort {}

class _Connections extends Mock implements WalletConnectionPort {}

final class _ProbedKeystore extends FakeSecureStoragePlatform {
  final Future<void> Function() _beforeRead;

  _ProbedKeystore(this._beforeRead);

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    await _beforeRead();
    return super.read(key: key, options: options);
  }
}

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
  late _Catalog catalog;
  late _Freezes freezes;
  Future<Result<void, SyncFailure>> Function(WalletKey) syncSource = (
    _,
  ) async => const Ok(null);
  Future<Result<void, SyncFailure>> sourceSync(WalletKey key) =>
      syncSource(key);
  WalletRegistration registration({Fingerprint? parent}) =>
      walletRegistrationForTesting(
        id: fundingWalletId,
        network: BitcoinNetwork.regtest,
        isDefault: true,
        signer: WalletSigner.local,
        masterFingerprint: parent ?? Fingerprint('00112233'),
        secretFingerprint: parent ?? Fingerprint('00112233'),
        derivationPath: "m/84'/1'/0'",
      );
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
    inventory: metadata,
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
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => fixture.directory.path,
    );
    final connections = _Connections();
    final engine = ElectrumSync(
      connections: connections,
      documentsDirectory: () async => fixture.directory.path,
      readRevision: (_) async => const Err(SyncNotFoundFailure()),
    );
    catalog = _Catalog();
    freezes = _Freezes();
    when(freezes.readAll).thenAnswer((_) async => const Ok([]));
    runtime = WalletNativeRuntime.open(
      catalog: catalog,
      reserved: _Reserved(),
      inputReservations: fixture.store,
      fundingReservations: fixture.store,
      deleteCatalogEntry: (key) async {
        return const Ok(null);
      },
      sync: engine,
      documentsDirectory: () async => fixture.directory.path,
      freezes: freezes,
      connections: connections,
    );
    selectSource = (_) async => fundingWalletId;
    syncSource = (_) async => const Ok(null);
    when(
      () => metadata.readWallet(any()),
    ).thenAnswer((_) async => const Err(WalletRegistrationNotFoundFailure()));
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

  Future<WalletRevision> openNativeSource() async {
    // Public BIP84 account descriptor of the published test vector.
    const xpub =
        'tpubDC8msFGeGuwnKG9Upg7DM2b4DaRqg3CUZa5g8v2SRQ6K4NSkxUgd7HsL2XVWbVm39y'
        'BA4LAxysQAm397zwQSQoQgewGiYZqrA9DsP4zbQ1M';
    final descriptor = BitcoinWalletDescriptor(
      key: fundingKey,
      scriptType: ScriptType.bip84,
      origin: 'fixture',
      externalDescriptor: 'wpkh($xpub/0/*)',
      internalDescriptor: 'wpkh($xpub/1/*)',
    );
    when(() => metadata.readWallet(fundingWalletId))
        .thenAnswer((_) async => Ok(registration()));
    when(catalog.list).thenAnswer((_) async => Ok([descriptor]));
    when(() => catalog.find(fundingKey))
        .thenAnswer((_) async => Ok(descriptor));
    sourceOk(await runtime.initialize());
    return sourceOk(await runtime.readRevision(fundingKey)).stamp;
  }

  test(
    'reconcile closes a never-prepared request under the native revision',
    () async {
      final stamp = await openNativeSource();
      sourceOk(
        await fixture.store.begin(
          operationId: 'never-prepared',
          accountIdentity: account.canonical,
          sourceParent: account.parent,
          key: fundingKey,
          generation: stamp.generation,
          context: 'public-context',
        ),
      );
      expect(await actor.reconcileSource('never-prepared'), isA<Ok>());
      expect(
        sourceOk(await fixture.store.pendingForAccount(account.canonical)),
        isNull,
      );
      expect(keystore.reads, 0);
    },
  );

  test(
    'reconcile tombstones an unregistered and never-signed reservation',
    () async {
      await openNativeSource();
      await fixture.reserve('unregistered', account: account.canonical);
      expect(
        sourceOk(
          await fixture.store.unregisteredNeverSignedBoard('unregistered'),
        ),
        isTrue,
      );
      expect(await actor.reconcileSource('unregistered'), isA<Ok>());
      expect(
        sourceOk(await fixture.store.pendingForAccount(account.canonical)),
        isNull,
      );
      expect(sourceOk(await fixture.store.reservations()), isEmpty);
      expect(keystore.reads, 0);
    },
  );

  test('exit signing can fetch its key only after the durable seal and lease release', () async {
    final stamp = await openNativeSource();
    final output = sourceOk(inspectBitcoinPsbt(publicFundingPsbt))
        .outputs
        .single;
    final address = sourceOk(
      bitcoinScriptAddress(output.scriptPubkey, account.network),
    );
    final chain = Uri.parse('http://chain.invalid');
    final id = 'exit-reserve-${sha256.convert(utf8.encode(account.canonical))}';
    final context = jsonEncode({
      'version': 1,
      'type': 'exitReserve',
      'account': account.canonical,
      'ids': ['fixture'],
      'destination': address,
      'reserveAddress': address,
      'chainSource': chain.toString(),
      'sats': output.valueSat.toString(),
    });
    sourceOk(
      await fixture.store.beginExitReserveRequest(
        operationId: id,
        accountIdentity: account.canonical,
        sourceParent: account.parent,
        key: fundingKey,
        generation: stamp.generation,
        context: context,
      ),
    );
    sourceOk(
      await fixture.store.reserve(
        key: fundingKey,
        spend: UnsignedSpend(
          revision: stamp,
          encoded: publicFundingPsbt,
          inputs: decodeBitcoinPsbt(publicFundingPsbt).inputs,
          owner: SpendOwner(protocol: 'ark', session: id),
        ),
        context: context,
      ),
    );
    final binding = sourceOk(await fixture.store.readBinding(id));
    var keystoreReached = false;
    _ProbedKeystore(() async {
      // Reacquire the actual spend gate at the first read of the signer key.
      // The previous gate must already be released, and the CAS already durable.
      sourceOk(
        await runtime.withBitcoinRevisionAdmission(fundingKey, (
          admitted,
        ) async {
          expect(admitted, stamp);
          expect(
            await fixture.store.admitExitReserveSigning(
              expected: binding,
              admittedRevision: admitted,
            ),
            isA<Err>().having(
              (err) => err.failure,
              'the single-use seal was consumed',
              isA<SyncSpendRefusedFailure>(),
            ),
          );
        }),
      );
      keystoreReached = true;
      // No key was installed: this fixture stops before producing a signature.
    }).install();
    final result = await actor.fundInitialExit(
      ArkQuote(
        id: 'fixture',
        account: account,
        generation: 1,
        chainSource: chain,
        configGeneration: 1,
        kind: ArkOperationKind.emergencyExit,
        amount: Sats.fromInt(output.valueSat),
        fee: Sats.fromInt(output.valueSat - 1000),
        net: Sats.fromInt(1000),
        selectedIds: ['fixture'],
        destination: address,
        observedTip: 1,
        validUntil: DateTime.utc(2100),
      ),
      address,
      isCurrent: () => true,
    );
    expect(
      result,
      isA<Err>().having(
        (err) => err.failure,
        'failure',
        isA<ArkAccountRecoveryFailure>(),
      ),
    );
    expect(keystoreReached, isTrue);
  });

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

  for (final candidate in [
    walletRegistrationForTesting(
      id: fundingWalletId,
      network: BitcoinNetwork.regtest,
      isDefault: true,
      signer: WalletSigner.local,
      secretFingerprint: Fingerprint('00112233'),
      derivationPath: "m/84'/1'/1'",
    ),
    walletRegistrationForTesting(
      id: fundingWalletId,
      network: BitcoinNetwork.regtest,
      isDefault: true,
      signer: WalletSigner.local,
      secretFingerprint: Fingerprint('00112233'),
      derivationPath: null,
    ),
    walletRegistrationForTesting(
      id: fundingWalletId,
      network: BitcoinNetwork.regtest,
      signer: WalletSigner.local,
      secretFingerprint: Fingerprint('00112233'),
      derivationPath: "m/84'/1'/0'",
    ),
    walletRegistrationForTesting(
      id: fundingWalletId,
      network: BitcoinNetwork.regtest,
      isDefault: true,
      signer: WalletSigner.none,
      derivationPath: "m/84'/1'/0'",
    ),
  ]) {
    test(
      'refuses ineligible source ${candidate.signer} ${candidate.derivationPath} ${candidate.isDefault}',
      () async {
        when(() => metadata.readWallet(fundingWalletId))
            .thenAnswer((_) async => Ok(candidate));
        final result = await actor.prepare(
          config(account),
          Sats.fromInt(20000),
        );
        expect(result, isA<Err<ArkBoardPreparation, ArkFailure>>());
        verifyZeroInteractions(client);
        verifyZeroInteractions(fees);
        verifyZeroInteractions(custody);
        expect(keystore.reads, 0);
      },
    );
  }

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
  test(
    'a failed source sync is ignored before reading the native source',
    () async {
      final synced = <WalletKey>[];
      syncSource = (key) async {
        synced.add(key);
        return const Err(SyncBusyFailure());
      };
      when(() => metadata.readWallet(fundingWalletId))
          .thenAnswer((_) async => Ok(registration()));
      final source = WalletKey(
        id: fundingWalletId,
        network: BitcoinNetwork.regtest,
      );
      when(catalog.list).thenAnswer((_) async => const Ok([]));
      when(() => catalog.find(source))
          .thenAnswer((_) async => const Err(SyncStorageFailure()));
      final result = await actor.prepare(config(account), Sats.fromInt(20000));
      expect(synced, [source]);
      verify(() => catalog.find(source)).called(1);
      expect(
        result,
        isA<Err<ArkBoardPreparation, ArkFailure>>().having(
          (r) => r.failure,
          'native source failure',
          isA<ArkFeatureStorageFailure>(),
        ),
      );
      expect(keystore.reads, 0);
      verifyZeroInteractions(client);
    },
  );
  test(
    'a failed source sync refuses reconcile and leaves the operation pending',
    () async {
      await fixture.reserve('operation', account: account.canonical);
      syncSource = (_) async => const Err(SyncBusyFailure());
      when(() => metadata.readWallet(fundingWalletId))
          .thenAnswer((_) async => Ok(registration()));
      final source = WalletKey(
        id: fundingWalletId,
        network: BitcoinNetwork.regtest,
      );
      when(() => catalog.find(source))
          .thenAnswer((_) async => const Err(SyncStorageFailure()));
      when(catalog.list).thenAnswer((_) async => const Ok([]));
      final before = sourceOk(await fixture.store.readBinding('operation'));
      expect(
        await actor.reconcileSource('operation'),
        isA<Err<void, ArkFailure>>().having(
          (result) => result.failure,
          'retryable source failure',
          isA<ArkOperationBusyFailure>(),
        ),
      );
      // A source that could not be refreshed is never read: the journal keeps
      // its pending operation for the next reconcile instead.
      verifyNever(() => catalog.find(source));
      expect(
        sourceOk(await fixture.store.pendingForAccount(account.canonical)),
        'operation',
      );
      final after = sourceOk(await fixture.store.readBinding('operation'));
      expect(
        (after.unsignedTxid, after.context),
        (before.unsignedTxid, before.context),
      );
      expect(keystore.reads, 0);
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
    verifyNever(() => metadata.readWallet(any()));
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
    verifyNever(() => metadata.readWallet(any()));
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
      verifyNever(() => metadata.readWallet(any()));
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
        verifyNever(() => metadata.readWallet(any()));
        expect(
          sourceOk(await fixture.store.readBoardReview('operation')).phase,
          phase,
        );
      },
    );
  }
  test(
    'resuming a signed Board never signs again, and waits when checks fail',
    () async {
      final data = await review();
      sourceOk(
        await fixture.store.admitBoardSigning(
          expected: data.$1,
          admittedRevision: fundingStamp,
        ),
      );
      sourceOk(
        await fixture.store.recordSigned('operation', structuralFinalWitness()),
      );
      sourceOk(
        await fixture.store.advanceBoardDelivery(
          'operation',
          expectedPhase: 'signing',
          nextPhase: 'signed',
        ),
      );
      final result = await actor.deliverSigned(account, 'operation');
      // Whatever the checks answer here, the stored signature is the only
      // one: the keystore is never read again.
      expect(keystore.reads, 0);
      if (result is Err) {
        // Refused: nothing moved, the Board waits for the next check.
        expect(
          sourceOk(await fixture.store.readBoardReview('operation')).phase,
          'signed',
        );
      }
    },
  );
  test(
    'an expired original review refuses before any provider or signer stage',
    () async {
      final data = await review(
        validUntil: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      );
      when(() => metadata.readWallet(fundingWalletId))
          .thenAnswer((_) async => Ok(registration()));
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
      when(() => metadata.readWallet(fundingWalletId))
          .thenAnswer((_) async => Ok(registration()));
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
    when(() => metadata.readWallet(fundingWalletId))
        .thenAnswer((_) async => Ok(registration()));
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
      when(() => metadata.readWallet(fundingWalletId)).thenAnswer(
        (_) async => Ok(registration(parent: Fingerprint('ffeeddcc'))),
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
        inventory: metadata,
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
      inventory: metadata,
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
