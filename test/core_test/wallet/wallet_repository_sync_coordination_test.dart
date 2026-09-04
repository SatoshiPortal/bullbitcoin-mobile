import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart'
    show InMemoryWalletSourceOperationCoordinator, WalletSourceKey;

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _ImmediateElectrumPort implements ElectrumServersPort {
  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) => operation(
    const ElectrumConnection(
      url: 'electrum.example',
      retry: 0,
      timeout: 30,
      stopGap: 20,
      validateDomain: true,
      isCustom: false,
    ),
  );
}

const _walletId = 'wpkh([73c5da0a/84h/1h/0h])';
const _otherWalletId = 'wpkh([deadbeef/84h/1h/0h])';
const _liquidWalletId = 'elwpkh([73c5da0a/84h/1h/0h])';

const _metadata = WalletMetadataModel(
  id: _walletId,
  masterFingerprint: '73c5da0a',
  xpubFingerprint: 'deadbeef',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'tpub-test',
  externalPublicDescriptor: 'wpkh(external)',
  internalPublicDescriptor: 'wpkh(internal)',
  signer: Signer.local,
  isDefault: true,
);

Wallet _wallet(String id, {Network network = Network.bitcoinTestnet}) => Wallet(
  origin: id,
  network: network,
  xpubFingerprint: 'deadbeef',
  scriptType: ScriptType.bip84,
  xpub: 'tpub-test',
  externalPublicDescriptor: 'wpkh(external)',
  internalPublicDescriptor: 'wpkh(internal)',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicBdk(
        id: _walletId,
        externalDescriptor: 'wpkh(external)',
        internalDescriptor: 'wpkh(internal)',
        isTestnet: true,
      ),
    );
    registerFallbackValue(
      const WalletModel.publicLwk(
        id: _liquidWalletId,
        combinedCtDescriptor: 'elwpkh(external)',
        isTestnet: true,
      ),
    );
    registerFallbackValue(_metadata);
    registerFallbackValue(
      const ElectrumConnection(
        url: 'electrum.example',
        retry: 0,
        timeout: 30,
        stopGap: 20,
        validateDomain: true,
        isCustom: false,
      ),
    );
  });

  test('waits for an externally held BDK source key', () async {
    final bdk = _MockBdkWalletDatasource();
    final lwk = _MockLwkWalletDatasource();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    final entered = Completer<void>();
    final release = Completer<void>();
    when(() => bdk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(
      () => bdk.sync(
        wallet: any(named: 'wallet'),
        electrumServer: any(named: 'electrumServer'),
      ),
    ).thenAnswer((_) async {
      entered.complete();
      await release.future;
    });
    final repository = WalletRepository(
      walletMetadataDatasource: _MockWalletMetadataDatasource(),
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: _ImmediateElectrumPort(),
      coordinator: coordinator,
    );
    final key = const WalletSourceKey(_walletId, 'bitcoin', 'testnet');
    final holderRelease = Completer<void>();
    final holder = coordinator.runExclusive<void>(
      key,
      (_) => holderRelease.future,
    );
    final sync = repository.sync(_wallet(_walletId));

    await Future<void>.delayed(Duration.zero);
    expect(entered.isCompleted, isFalse);
    holderRelease.complete();
    await holder;
    release.complete();
    await sync;
  });

  test('delivers a start ID while the same source key is held', () async {
    final bdk = _MockBdkWalletDatasource();
    final lwk = _MockLwkWalletDatasource();
    final metadata = _MockWalletMetadataDatasource();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    final starts = StreamController<String>.broadcast();
    addTearDown(starts.close);
    when(() => bdk.walletSyncStartedStream).thenAnswer((_) => starts.stream);
    when(() => bdk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    final repository = WalletRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: _ImmediateElectrumPort(),
      coordinator: coordinator,
    );
    final held = Completer<void>();
    final holder = coordinator.runExclusive<void>(
      const WalletSourceKey(_walletId, 'bitcoin', 'testnet'),
      (_) => held.future,
    );

    final observed = repository.walletSyncStartedIdsStream.first;
    starts.add(_walletId);

    expect(await observed, _walletId);
    verifyNever(() => metadata.fetch(any()));
    held.complete();
    await holder;
  });

  test('does not block a BDK wallet with a different source key', () async {
    final bdk = _MockBdkWalletDatasource();
    final lwk = _MockLwkWalletDatasource();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    final entered = Completer<void>();
    when(() => bdk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(
      () => bdk.sync(
        wallet: any(named: 'wallet'),
        electrumServer: any(named: 'electrumServer'),
      ),
    ).thenAnswer((_) async => entered.complete());
    final repository = WalletRepository(
      walletMetadataDatasource: _MockWalletMetadataDatasource(),
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: _ImmediateElectrumPort(),
      coordinator: coordinator,
    );
    final held = Completer<void>();
    final holder = coordinator.runExclusive<void>(
      const WalletSourceKey(_walletId, 'bitcoin', 'testnet'),
      (_) => held.future,
    );

    await repository.sync(_wallet(_otherWalletId));
    expect(entered.isCompleted, isTrue);
    held.complete();
    await holder;
  });

  test('releases the source key after a failed BDK sync', () async {
    final bdk = _MockBdkWalletDatasource();
    final lwk = _MockLwkWalletDatasource();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    var attempts = 0;
    when(() => bdk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(
      () => bdk.sync(
        wallet: any(named: 'wallet'),
        electrumServer: any(named: 'electrumServer'),
      ),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) {
        throw NoElectrumServersConfiguredException(
          ElectrumServerNetwork.bitcoinTestnet,
        );
      }
    });
    final repository = WalletRepository(
      walletMetadataDatasource: _MockWalletMetadataDatasource(),
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: _ImmediateElectrumPort(),
      coordinator: coordinator,
    );
    final failedResult = repository.electrumSyncResultStream.first;
    await expectLater(
      repository.sync(_wallet(_walletId)),
      throwsA(isA<NoElectrumServersConfiguredException>()),
    );
    expect((await failedResult).success, isFalse);
    final successResult = repository.electrumSyncResultStream.first;
    await repository.sync(_wallet(_walletId));
    expect((await successResult).success, isTrue);
    expect(attempts, 2);
  });

  test('waits for the source key before reading a BDK balance', () async {
    final metadata = _MockWalletMetadataDatasource();
    final bdk = _MockBdkWalletDatasource();
    final lwk = _MockLwkWalletDatasource();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    final entered = Completer<void>();
    final release = Completer<void>();
    when(() => metadata.fetch(_walletId)).thenAnswer((_) async => _metadata);
    when(() => bdk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.getBalance(wallet: any(named: 'wallet'))).thenAnswer((
      _,
    ) async {
      entered.complete();
      await release.future;
      return BalanceModel(
        confirmedSat: BigInt.from(100),
        immatureSat: BigInt.zero,
        trustedPendingSat: BigInt.zero,
        untrustedPendingSat: BigInt.zero,
        spendableSat: BigInt.from(100),
        totalSat: BigInt.from(100),
      );
    });
    final repository = WalletRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: _ImmediateElectrumPort(),
      coordinator: coordinator,
    );
    final holderRelease = Completer<void>();
    final holder = coordinator.runExclusive<void>(
      const WalletSourceKey(_walletId, 'bitcoin', 'testnet'),
      (_) => holderRelease.future,
    );
    final balances = repository.getWalletBalances(walletId: _walletId);
    await Future<void>.delayed(Duration.zero);
    expect(entered.isCompleted, isFalse);
    holderRelease.complete();
    await holder;
    await entered.future;
    release.complete();
    expect((await balances).totalSat, 100);
  });

  test('waits for BDK deletion and deletes metadata afterwards', () async {
    final metadata = _MockWalletMetadataDatasource();
    final bdk = _MockBdkWalletDatasource();
    final lwk = _MockLwkWalletDatasource();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    final release = Completer<void>();
    final events = <String>[];
    when(() => metadata.fetch(_walletId)).thenAnswer((_) async => _metadata);
    when(() => metadata.delete(_walletId)).thenAnswer((_) async {
      events.add('metadata');
    });
    when(() => bdk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.delete(wallet: any(named: 'wallet'))).thenAnswer((_) async {
      events.add('source');
      await release.future;
    });
    final repository = WalletRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: _ImmediateElectrumPort(),
      coordinator: coordinator,
    );
    final holderRelease = Completer<void>();
    final holder = coordinator.runExclusive<void>(
      const WalletSourceKey(_walletId, 'bitcoin', 'testnet'),
      (_) => holderRelease.future,
    );
    final deletion = repository.deleteWallet(walletId: _walletId);
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    holderRelease.complete();
    await holder;
    await Future<void>.delayed(Duration.zero);
    expect(events, ['source']);
    release.complete();
    await deletion;
    expect(events, ['source', 'metadata']);
  });

  test(
    'metadata delete failure does not strand BDK source retirement',
    () async {
      final metadata = _MockWalletMetadataDatasource();
      final bdk = _MockBdkWalletDatasource();
      final lwk = _MockLwkWalletDatasource();
      final coordinator = InMemoryWalletSourceOperationCoordinator();
      var deleteFailures = 1;
      when(() => metadata.fetch(_walletId)).thenAnswer((_) async => _metadata);
      when(() => metadata.delete(_walletId)).thenAnswer((_) async {
        if (deleteFailures-- > 0) throw StateError('metadata delete failed');
      });
      when(() => bdk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
      when(
        () => bdk.walletSyncFinishedStream,
      ).thenAnswer((_) => Stream.empty());
      when(() => lwk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
      when(
        () => lwk.walletSyncFinishedStream,
      ).thenAnswer((_) => Stream.empty());
      when(
        () => bdk.delete(wallet: any(named: 'wallet')),
      ).thenAnswer((_) async {});
      final repository = WalletRepository(
        walletMetadataDatasource: metadata,
        bdkWalletDatasource: bdk,
        lwkWalletDatasource: lwk,
        serversPort: _ImmediateElectrumPort(),
        coordinator: coordinator,
      );

      await expectLater(
        repository.deleteWallet(walletId: _walletId),
        throwsStateError,
      );
      expect(
        await coordinator.runExclusive(
          const WalletSourceKey(_walletId, 'bitcoin', 'testnet'),
          (_) async => true,
        ),
        isTrue,
      );
      await repository.deleteWallet(walletId: _walletId);
      await expectLater(
        coordinator.runExclusive(
          const WalletSourceKey(_walletId, 'bitcoin', 'testnet'),
          (_) async {},
        ),
        throwsStateError,
      );
    },
  );

  test(
    'failed creation stays retired until metadata finalization succeeds',
    () async {
      final metadata = _MockWalletMetadataDatasource();
      final bdk = _MockBdkWalletDatasource();
      final lwk = _MockLwkWalletDatasource();
      final coordinator = InMemoryWalletSourceOperationCoordinator();
      final seed = Seed.mnemonic(
        mnemonicWords:
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
                .split(' '),
        bytes: Uint8List.fromList(List<int>.generate(32, (index) => index)),
        masterFingerprint: '73c5da0a',
      );
      final derived = await WalletMetadataService.deriveFromSeed(
        seed: seed,
        network: Network.bitcoinTestnet,
        scriptType: ScriptType.bip84,
        isDefault: false,
      );
      final key = WalletSourceKey(derived.id, 'bitcoin', 'testnet');
      await coordinator.runExclusive(key, (session) async => session.retire());
      var storeFailures = 1;
      when(() => bdk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
      when(
        () => bdk.walletSyncFinishedStream,
      ).thenAnswer((_) => Stream.empty());
      when(() => lwk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
      when(
        () => lwk.walletSyncFinishedStream,
      ).thenAnswer((_) => Stream.empty());
      when(() => bdk.getBalance(wallet: any(named: 'wallet'))).thenAnswer(
        (_) async => BalanceModel(
          confirmedSat: BigInt.zero,
          immatureSat: BigInt.zero,
          trustedPendingSat: BigInt.zero,
          untrustedPendingSat: BigInt.zero,
          spendableSat: BigInt.zero,
          totalSat: BigInt.zero,
        ),
      );
      when(() => metadata.store(any())).thenAnswer((_) async {
        if (storeFailures-- > 0) throw StateError('metadata store failed');
      });
      final repository = WalletRepository(
        walletMetadataDatasource: metadata,
        bdkWalletDatasource: bdk,
        lwkWalletDatasource: lwk,
        serversPort: _ImmediateElectrumPort(),
        coordinator: coordinator,
      );

      await expectLater(
        repository.createWallet(
          seed: seed,
          network: Network.bitcoinTestnet,
          scriptType: ScriptType.bip84,
        ),
        throwsStateError,
      );
      await expectLater(
        coordinator.runExclusive(key, (_) async {}),
        throwsStateError,
      );

      await repository.createWallet(
        seed: seed,
        network: Network.bitcoinTestnet,
        scriptType: ScriptType.bip84,
      );
      expect(await coordinator.runExclusive(key, (_) async => true), isTrue);
    },
  );

  test('rejects stale Liquid amount lookup after source deletion', () async {
    final metadata = _MockWalletMetadataDatasource();
    final bdk = _MockBdkWalletDatasource();
    final lwk = _MockLwkWalletDatasource();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    when(() => bdk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(
      () => metadata.fetch(_liquidWalletId),
    ).thenAnswer((_) async => _metadata.copyWith(id: _liquidWalletId));
    when(
      () => lwk.getAmountSentToAddress(
        any(),
        any(),
        wallet: any(named: 'wallet'),
      ),
    ).thenAnswer((_) async => 1);
    final repository = WalletRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: _ImmediateElectrumPort(),
      coordinator: coordinator,
    );
    await coordinator.runExclusive(
      const WalletSourceKey(_liquidWalletId, 'liquid', 'testnet'),
      (session) async {
        session.retire();
      },
    );

    await expectLater(
      repository.getAmountSentToAddress(
        psbtOrPset: 'pset',
        address: 'el1-address',
        walletId: _liquidWalletId,
      ),
      throwsStateError,
    );
    verifyNever(
      () => lwk.getAmountSentToAddress(
        any(),
        any(),
        wallet: any(named: 'wallet'),
      ),
    );
  });

  test(
    'does not reopen a wallet after deletion wins after metadata retrieval',
    () async {
      final metadata = _MockWalletMetadataDatasource();
      final bdk = _MockBdkWalletDatasource();
      final lwk = _MockLwkWalletDatasource();
      final coordinator = InMemoryWalletSourceOperationCoordinator();
      final metadataRetrieved = Completer<void>();
      final resumeMetadataFetch = Completer<void>();
      var fetches = 0;
      var balanceCalls = 0;
      var metadataExists = true;
      when(() => metadata.fetch(_walletId)).thenAnswer((_) async {
        fetches++;
        if (fetches == 1) {
          metadataRetrieved.complete();
          await resumeMetadataFetch.future;
        }
        return metadataExists ? _metadata : null;
      });
      when(() => metadata.delete(_walletId)).thenAnswer((_) async {
        metadataExists = false;
      });
      when(() => bdk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
      when(
        () => bdk.walletSyncFinishedStream,
      ).thenAnswer((_) => Stream.empty());
      when(() => lwk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
      when(
        () => lwk.walletSyncFinishedStream,
      ).thenAnswer((_) => Stream.empty());
      when(
        () => bdk.delete(wallet: any(named: 'wallet')),
      ).thenAnswer((_) async {});
      when(() => bdk.getBalance(wallet: any(named: 'wallet'))).thenAnswer((
        _,
      ) async {
        balanceCalls++;
        return BalanceModel(
          confirmedSat: BigInt.zero,
          immatureSat: BigInt.zero,
          trustedPendingSat: BigInt.zero,
          untrustedPendingSat: BigInt.zero,
          spendableSat: BigInt.zero,
          totalSat: BigInt.zero,
        );
      });
      final repository = WalletRepository(
        walletMetadataDatasource: metadata,
        bdkWalletDatasource: bdk,
        lwkWalletDatasource: lwk,
        serversPort: _ImmediateElectrumPort(),
        coordinator: coordinator,
      );

      final operation = repository.getWallet(_walletId);
      await metadataRetrieved.future;
      final deletion = repository.deleteWallet(walletId: _walletId);
      resumeMetadataFetch.complete();

      await deletion;
      await expectLater(operation, throwsStateError);
      expect(
        balanceCalls,
        0,
        reason: 'a stale operation must not recreate the deleted BDK source',
      );
    },
  );

  test('serializes operations for the same LWK source key', () async {
    final bdk = _MockBdkWalletDatasource();
    final lwk = _MockLwkWalletDatasource();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    final entered = Completer<void>();
    final release = Completer<void>();
    var calls = 0;
    when(() => lwk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(
      () => lwk.sync(
        wallet: any(named: 'wallet'),
        electrumServer: any(named: 'electrumServer'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        entered.complete();
        await release.future;
      }
    });
    final repository = WalletRepository(
      walletMetadataDatasource: _MockWalletMetadataDatasource(),
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: _ImmediateElectrumPort(),
      coordinator: coordinator,
    );

    final first = repository.sync(
      _wallet(_liquidWalletId, network: Network.liquidTestnet),
    );
    await entered.future;
    final second = repository.sync(
      _wallet(_liquidWalletId, network: Network.liquidTestnet),
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    release.complete();
    await Future.wait([first, second]);
    expect(calls, 2);
  });

  test('keeps LWK sync and balance in one coordinated operation', () async {
    final metadata = _MockWalletMetadataDatasource();
    final bdk = _MockBdkWalletDatasource();
    final lwk = _MockLwkWalletDatasource();
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    final events = <String>[];
    when(
      () => metadata.fetch(_liquidWalletId),
    ).thenAnswer((_) async => _metadata.copyWith(id: _liquidWalletId));
    when(() => lwk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(
      () => lwk.sync(
        wallet: any(named: 'wallet'),
        electrumServer: any(named: 'electrumServer'),
      ),
    ).thenAnswer((_) async => events.add('sync'));
    when(() => lwk.getBalance(wallet: any(named: 'wallet'))).thenAnswer((
      _,
    ) async {
      events.add('balance');
      return BalanceModel(
        confirmedSat: BigInt.from(100),
        immatureSat: BigInt.zero,
        trustedPendingSat: BigInt.zero,
        untrustedPendingSat: BigInt.zero,
        spendableSat: BigInt.from(100),
        totalSat: BigInt.from(100),
      );
    });
    final repository = WalletRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: _ImmediateElectrumPort(),
      coordinator: coordinator,
    );

    await repository.getWallet(_liquidWalletId, sync: true);
    expect(events, ['sync', 'balance']);
  });

  test('deletes the LWK source before wallet metadata', () async {
    final metadata = _MockWalletMetadataDatasource();
    final bdk = _MockBdkWalletDatasource();
    final lwk = _MockLwkWalletDatasource();
    final events = <String>[];
    when(
      () => metadata.fetch(_liquidWalletId),
    ).thenAnswer((_) async => _metadata.copyWith(id: _liquidWalletId));
    when(() => metadata.delete(_liquidWalletId)).thenAnswer((_) async {
      events.add('metadata');
    });
    when(() => lwk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.walletSyncStartedStream).thenAnswer((_) => Stream.empty());
    when(() => bdk.walletSyncFinishedStream).thenAnswer((_) => Stream.empty());
    when(() => lwk.delete(wallet: any(named: 'wallet'))).thenAnswer((_) async {
      events.add('source');
    });
    final repository = WalletRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: _ImmediateElectrumPort(),
      coordinator: InMemoryWalletSourceOperationCoordinator(),
    );

    await repository.deleteWallet(walletId: _liquidWalletId);
    expect(events, ['source', 'metadata']);
  });
}
