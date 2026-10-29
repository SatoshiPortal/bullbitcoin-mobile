import 'package:bb_mobile/core/wallet/domain/wallet_payment_observation_port.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:notifications/notifications.dart';
import 'dart:io';
import 'dart:async';
import 'package:bb_mobile/core/wallet/data/cbf_privacy_guard.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:drift/native.dart';
import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:transaction_sync/transaction_sync.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Settings extends Mock implements SettingsRepository {}

class _Servers extends Mock implements ElectrumServersPort {}

class _Bitcoin extends Mock implements BitcoinWalletRepository {}

class _Mnemonic extends Fake implements bip39.Mnemonic {}

class _Facade extends Mock implements WalletTransactionSyncFacade {}

class _NotificationGateway extends Fake implements LocalNotificationGateway {
  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async =>
      const Ok(false);
}

class _Bdk extends Mock implements BdkWalletDatasource {}

class _Lwk extends Mock implements LwkWalletDatasource {}

class _Blockchain extends Mock implements BdkBitcoinBlockchainDatasource {}

class _SyncMetadata extends Mock implements WalletSyncMetadataPort {}

class _Payments extends Mock implements WalletPaymentObservationPort {}

const _id = 'wpkh([deadbeef/84h/0h/0h])';
const _key = WalletNetworkKey(_id, 'bitcoin', 'mainnet');
const _registration = WalletSourceRegistration(
  key: _key,
  sourceKind: 'bdk_electrum',
  configurationFingerprint: 'public',
);

WalletMetadataModel _metadata() => const WalletMetadataModel(
  id: _id,
  masterFingerprint: 'deadbeef',
  xpubFingerprint: 'public',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'public',
  externalPublicDescriptor: 'wpkh(public/0/*)',
  internalPublicDescriptor: 'wpkh(public/1/*)',
  signer: Signer.none,
  isDefault: false,
  bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const SynchronizeWalletRequest(_registration));
    registerFallbackValue(_registration);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      const WalletModel.publicBdk(
        id: _id,
        externalDescriptor: 'public',
        internalDescriptor: 'public',
        isTestnet: false,
      ),
    );
  });
  late _Metadata metadata;
  late _Settings settings;
  late _Servers servers;
  late _Facade facade;
  late InMemoryWalletSourceOperationCoordinator coordinator;
  late BitcoinSyncRouting routing;
  setUp(() {
    metadata = _Metadata();
    settings = _Settings();
    servers = _Servers();
    facade = _Facade();
    coordinator = InMemoryWalletSourceOperationCoordinator();
    when(() => facade.stopCbfNodes()).thenAnswer((_) async => const Ok(null));
    when(
      () => facade.stageCbfTransaction(
        registration: any(named: 'registration'),
        transactionBytes: any(named: 'transactionBytes'),
      ),
    ).thenAnswer((_) async => const Ok('pending'));
    when(() => metadata.fetch(_id)).thenAnswer((_) async => _metadata());
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    routing = BitcoinSyncRouting(
      facade: facade,
      settings: settings,
      tor: () => throw StateError('No direct fallback'),
      documentsDirectory: () async => '/tmp/public-test',
    );
  });

  for (final (script, floor, birthday, knownCheckpoint) in [
    (
      'pkh',
      BitcoinSyncCheckpoint.bip32,
      DateTime.utc(2015, 6),
      BitcoinSyncCheckpoint(
        height: 354415,
        blockHash:
            '00000000000000000ae058802b739bcd6dcc2a168bbfeae4b3dc445811b29c3f',
        blockTimestamp: 1430437778,
      ),
    ),
    (
      'tr',
      BitcoinSyncCheckpoint.taproot,
      DateTime.utc(2022, 6),
      BitcoinSyncCheckpoint(
        height: 734314,
        blockHash:
            '00000000000000000001816587e0b34ced7cd31a5a6bc79cffe2d764e01091f4',
        blockTimestamp: 1651362911,
      ),
    ),
    (
      'wpkh',
      BitcoinSyncCheckpoint.segwit,
      DateTime.utc(2018, 6),
      BitcoinSyncCheckpoint(
        height: 520649,
        blockHash:
            '0000000000000000002d79741da44d81cfad4923802fa45d3d63d37295956d71',
        blockTimestamp: 1525132163,
      ),
    ),
  ]) {
    for (final known in [false, true]) {
      for (final testnet in [false, true]) {
        test(
          'CBF registration resolves $script with ${known ? 'known' : 'unknown'} birthday on ${testnet ? 'testnet' : 'mainnet'}',
          () async {
            // Keep a BIP84 identity: the persisted output script is authoritative.
            final record = _metadata().copyWith(
              id: testnet ? 'wpkh([deadbeef/84h/1h/0h])' : _id,
              externalPublicDescriptor: '$script(public/0/*)',
              internalPublicDescriptor: '$script(public/1/*)',
              birthday: known ? birthday : null,
            );
            final registration = await routing.registration(record);
            final expected = testnet
                ? BitcoinSyncCheckpoint.genesis(BitcoinNetwork.testnet)
                : known
                ? knownCheckpoint
                : floor;
            expect(
              registration.configuration,
              isA<BdkCbfConfiguration>()
                  .having((c) => c.checkpoint, 'checkpoint', expected)
                  .having(
                    (c) => c.checkpoint.timestamp,
                    'checkpoint timestamp',
                    expected.timestamp,
                  )
                  .having(
                    (c) => c.externalPublicDescriptor,
                    'persisted external descriptor',
                    record.externalPublicDescriptor,
                  )
                  .having((c) => c.isTestnet, 'network', testnet),
            );
          },
        );
      }
    }
  }

  test(
    'CBF import status refuses before settings, secrets or Electrum',
    () async {
      final bitcoin = _Bitcoin();
      await expectLater(
        CheckWalletStatusUsecase(settings, servers, bitcoin).call(
          mnemonic: _Mnemonic(),
          scriptType: ScriptType.bip84,
          bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
        ),
        throwsA(
          isA<BitcoinSyncOperationException>().having(
            (error) => error.failure,
            'failure',
            isA<CbfRemoteLookupForbiddenFailure>(),
          ),
        ),
      );
      verifyZeroInteractions(settings);
      verifyZeroInteractions(servers);
      verifyZeroInteractions(bitcoin);
    },
  );
  test(
    'background facade routing defers first recovery without retry backoff',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cbf-background-facade',
      );
      addTearDown(() => directory.delete(recursive: true));
      final outbox = SqliteNotificationOutbox(
        databasePath: '${directory.path}/notifications.sqlite',
      );
      addTearDown(outbox.dispose);
      final notifications = NotificationsFacade(
        gateway: _NotificationGateway(),
        outbox: outbox,
      );
      final queue = SqliteWalletSyncJobQueue(
        databasePath: '${directory.path}/q.sqlite',
      );
      addTearDown(queue.close);
      final deadline = DateTime.now().toUtc().add(const Duration(minutes: 1));
      WalletSourceSession? admitted;
      when(() => facade.synchronizeWallet(any())).thenAnswer((
        invocation,
      ) async {
        final request =
            invocation.positionalArguments.single as SynchronizeWalletRequest;
        expect(identical(request.session, admitted), isTrue);
        expect(request.session?.isClosed, isFalse);
        expect(request.allowInitialScan, isFalse);
        final config = request.registration.configuration;
        expect(config, isA<BdkCbfConfiguration>());
        if (config is BdkCbfConfiguration) {
          expect(config.deadline, deadline);
          expect(config.electrumUrls, isEmpty);
          expect(config.checkpoint, BitcoinSyncCheckpoint.segwit);
        }
        return const Err(InitialScanRequiredFailure());
      });
      final admission = AdmitWalletSyncUsecase(
        coordinatorForTimeout: (_) => coordinator,
      );
      final job = WalletTransactionSyncBackgroundJob(
        key: _key,
        queueRevision: 'source-compactBlockFilters-cbf-v1',
        synchronize: () => admission.execute(
          key: const WalletSourceKey(_id, 'bitcoin', 'mainnet'),
          deadline: deadline,
          operation: (session) async {
            admitted = session;
            final wallet = await metadata.fetch(_id);
            if (wallet == null) return const Err(DeletedWalletFailure());
            return routing.synchronize(
              wallet,
              session,
              allowInitialScan: false,
              deadline: deadline,
            );
          },
        ),
      );
      final result = await WalletTransactionSyncBackgroundTask(
        notifications: notifications,
        queue: queue,
        jobs: [job],
        copy: (_, _) => (title: '', body: ''),
      ).execute(chain: 'bitcoin');
      expect(result.status, BackgroundTaskExecutionStatus.success);
      verify(() => facade.synchronizeWallet(any())).called(1);
      verifyZeroInteractions(servers);
      final claims = await queue.reconcileAndClaim([
        (key: _key, revision: job.queueRevision),
      ], chain: 'bitcoin');
      expect(claims, hasLength(1));
      expect(await queue.completeSuccess(claims.single), isTrue);
    },
  );

  test(
    'reactive CBF snapshot initializes the notification baseline without fee reads',
    () async {
      final bdk = _Bdk();
      final payments = _Payments();
      when(() => payments.recordSeen(_key, [])).thenAnswer((_) async {});
      final repository = WalletRepository(
        walletMetadataDatasource: metadata,
        bdkWalletDatasource: bdk,
        lwkWalletDatasource: _Lwk(),
        serversPort: servers,
        coordinator: coordinator,
        syncMetadata: _SyncMetadata(),
        paymentObservation: payments,
        bitcoinSyncRouting: routing,
      );
      await Future<void>.sync(() => repository.onCbfSnapshot(_key));
      verify(() => payments.recordSeen(_key, [])).called(1);
      verifyZeroInteractions(bdk);
      verifyZeroInteractions(servers);
    },
  );

  test(
    'CBF foreground sync preserves failure and makes zero Electrum calls',
    () async {
      final bdk = _Bdk();
      final lwk = _Lwk();
      final syncMetadata = _SyncMetadata();
      when(() => facade.synchronizeWallet(any())).thenAnswer((
        invocation,
      ) async {
        final request =
            invocation.positionalArguments.single as SynchronizeWalletRequest;
        expect(request.session, isNull);
        var admitted = false;
        await coordinator.runExclusive(
          const WalletSourceKey(_id, 'bitcoin', 'mainnet'),
          (_) async {
            admitted = true;
          },
        );
        expect(admitted, isTrue);
        expect(request.registration.configuration, isA<BdkCbfConfiguration>());
        return const Err(CbfNoPeersFailure());
      });
      final repository = WalletRepository(
        walletMetadataDatasource: metadata,
        bdkWalletDatasource: bdk,
        lwkWalletDatasource: lwk,
        serversPort: servers,
        coordinator: coordinator,
        syncMetadata: syncMetadata,
        bitcoinSyncRouting: routing,
      );
      final wallet = Wallet(
        origin: _id,
        network: Network.bitcoinMainnet,
        xpubFingerprint: 'public',
        scriptType: ScriptType.bip84,
        xpub: 'public',
        externalPublicDescriptor: 'public-external',
        internalPublicDescriptor: 'public-internal',
        signer: Signer.none.toEntity(),
        signerDevice: null,
        balanceSat: BigInt.zero,
      );
      await expectLater(
        SyncWalletUsecase(walletRepository: repository).execute(wallet),
        throwsA(
          isA<BitcoinSyncOperationException>().having(
            (error) => error.failure,
            'failure',
            isA<CbfNoPeersFailure>(),
          ),
        ),
      );
      verifyZeroInteractions(servers);
      verifyZeroInteractions(bdk);
    },
  );
  test(
    'CBF broadcast releases routing admission before P2P with zero Electrum',
    () async {
      final blockchain = _Blockchain();
      when(
        () => facade.broadcastCbfTransaction(
          registration: any(named: 'registration'),
          transactionBytes: any(named: 'transactionBytes'),
          session: any(named: 'session'),
        ),
      ).thenAnswer((_) async => const Err(CbfBroadcastNotRelayedFailure()));
      final repository = BitcoinBlockchainRepository(
        blockchainDatasource: blockchain,
        serversPort: servers,
        metadata: metadata,
        coordinator: coordinator,
        bitcoinSyncRouting: routing,
      );
      await expectLater(
        repository.broadcastTransaction(
          [1, 2],
          isTestnet: false,
          walletId: _id,
        ),
        throwsA(
          isA<BitcoinSyncOperationException>().having(
            (error) => error.failure,
            'failure',
            isA<CbfBroadcastNotRelayedFailure>(),
          ),
        ),
      );
      verifyZeroInteractions(servers);
      verifyZeroInteractions(blockchain);
    },
  );
  test('CBF pending is staged before Tor route verification', () async {
    final events = <String>[];
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
        useTorProxy: true,
      ),
    );
    when(
      () => facade.stageCbfTransaction(
        registration: any(named: 'registration'),
        transactionBytes: any(named: 'transactionBytes'),
      ),
    ).thenAnswer((_) async {
      events.add('pending');
      return const Ok('pending');
    });
    when(
      () => facade.broadcastCbfTransaction(
        registration: any(named: 'registration'),
        transactionBytes: any(named: 'transactionBytes'),
        session: any(named: 'session'),
      ),
    ).thenAnswer((_) async => const Err(CbfTorUnavailableFailure()));
    final route = BitcoinSyncRouting(
      facade: facade,
      settings: settings,
      documentsDirectory: () async => '/tmp/public-test',
      tor: () {
        events.add('verify');
        throw const FormatException('unreachable');
      },
    );
    await expectLater(
      route.broadcast(_metadata(), null, Uint8List.fromList([1])),
      throwsA(isA<BitcoinSyncOperationException>()),
    );
    expect(events, ['pending', 'verify']);
    verifyZeroInteractions(servers);
  });

  test(
    'Tor unavailable remains an explicit required route, never direct',
    () async {
      when(() => settings.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
          useTorProxy: true,
        ),
      );
      final registration = await routing.registration(_metadata());
      final configuration = registration.configuration as BdkCbfConfiguration;
      expect(configuration.torRequired, isTrue);
      expect(configuration.socksPort, isNull);
      verifyZeroInteractions(servers);
    },
  );
  test(
    'expired background deadline skips Tor verification and package work',
    () async {
      await coordinator.runExclusive(
        const WalletSourceKey(_id, 'bitcoin', 'mainnet'),
        (session) async {
          final result = await routing.synchronize(
            _metadata(),
            session,
            allowInitialScan: false,
            deadline: DateTime.utc(2000),
          );
          expect(
            result,
            isA<
              Err<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>
            >(),
          );
        },
      );
      verifyZeroInteractions(settings);
      verifyZeroInteractions(facade);
      verifyZeroInteractions(servers);
    },
  );
  test(
    'source changes wait until a guarded remote operation has settled',
    () async {
      var current = _metadata().copyWith(
        bitcoinSyncSource: BitcoinSyncSource.electrum,
      );
      when(() => metadata.fetch(_id)).thenAnswer((_) async => current);
      final guard = CbfPrivacyGuard(metadata, coordinator);
      final entered = Completer<void>();
      final release = Completer<void>();
      var calls = 0;
      final operation = guard.runElectrum([_id], () async {
        calls++;
        entered.complete();
        await release.future;
      });
      await entered.future;
      var changed = false;
      final change = coordinator.runExclusive(
        const WalletSourceKey(_id, 'bitcoin', 'mainnet'),
        (_) async {
          current = _metadata();
          changed = true;
        },
      );
      await coordinator.runExclusive(
        const WalletSourceKey('other', 'bitcoin', 'mainnet'),
        (_) async {},
      );
      expect(changed, isFalse);
      release.complete();
      await operation;
      await change;
      await expectLater(
        guard.runElectrum([_id], () async {
          calls++;
        }),
        throwsA(isA<BitcoinSyncOperationException>()),
      );
      expect(calls, 1);
    },
  );

  test(
    'a known Electrum wallet remains usable alongside an unrelated CBF wallet',
    () async {
      when(() => metadata.fetch(_id)).thenAnswer(
        (_) async =>
            _metadata().copyWith(bitcoinSyncSource: BitcoinSyncSource.electrum),
      );
      when(
        () => metadata.fetchAll(),
      ).thenAnswer((_) async => [_metadata().copyWith(id: 'unrelated-cbf')]);
      var calls = 0;
      await CbfPrivacyGuard(metadata, coordinator).runElectrum([_id], () async {
        calls++;
      });
      expect(calls, 1);
    },
  );

  test(
    'delete and reimport clear durable CBF discovery under source exclusion',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cbf-app-delete-',
      );
      final database = SqliteDatabase(NativeDatabase.memory());
      final store = WalletMetadataDatasource(sqlite: database);
      final syncMetadata = await SqliteWalletSyncMetadataStore.open(
        databasePath: '${directory.path}/metadata.sqlite',
      );
      final bdk = _Bdk();
      final lwk = _Lwk();
      when(
        () => bdk.delete(wallet: any(named: 'wallet')),
      ).thenAnswer((_) async {});
      await store.store(_metadata());
      await syncMetadata.completeCbfDiscovery(_key, 'policy');
      final repository = WalletRepository(
        walletMetadataDatasource: store,
        bdkWalletDatasource: bdk,
        lwkWalletDatasource: lwk,
        serversPort: servers,
        coordinator: coordinator,
        syncMetadata: syncMetadata,
        bitcoinSyncRouting: routing,
      );
      final deleted = await repository.deleteWallet(walletId: _id);
      expect(deleted, isA<Ok<void, dynamic>>());
      await store.store(_metadata());
      expect(
        await syncMetadata.isCbfDiscoveryComplete(_key, 'policy'),
        isFalse,
      );
      verifyZeroInteractions(servers);
      await syncMetadata.close();
      await database.close();
      await directory.delete(recursive: true);
    },
  );
  test(
    'CBF PSBT parsing failures discard foreign diagnostics before reporting',
    () async {
      final blockchain = _Blockchain();
      when(
        () => blockchain.extractFinalizedPsbt(any()),
      ).thenThrow(Exception('foreign transaction diagnostics'));
      final repository = BitcoinBlockchainRepository(
        blockchainDatasource: blockchain,
        serversPort: servers,
        metadata: metadata,
        coordinator: coordinator,
        bitcoinSyncRouting: routing,
      );
      await expectLater(
        repository.broadcastPsbt(
          'invalid-public-fixture',
          isTestnet: false,
          walletId: _id,
        ),
        throwsA(
          isA<BitcoinSyncOperationException>()
              .having(
                (error) => error.failure,
                'failure',
                isA<CbfBroadcastNotRelayedFailure>(),
              )
              .having(
                (error) => error.toString(),
                'sanitized diagnostic',
                isNot(contains('foreign transaction diagnostics')),
              ),
        ),
      );
      verifyZeroInteractions(servers);
      verifyZeroInteractions(facade);
    },
  );
}
