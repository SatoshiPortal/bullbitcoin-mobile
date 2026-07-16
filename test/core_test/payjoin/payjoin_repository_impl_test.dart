import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/pdk_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/payjoin/data/repository/payjoin_repository_impl.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart'
    show Signer;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart' show SignerEntity;
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalPayjoinDatasource extends Mock
    implements LocalPayjoinDatasource {}

class _MockPdkPayjoinDatasource extends Mock implements PdkPayjoinDatasource {}

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockSeedDatasource extends Mock implements SeedDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockBdkBitcoinBlockchainDatasource extends Mock
    implements BdkBitcoinBlockchainDatasource {}

class _MockElectrumServersPort extends Mock implements ElectrumServersPort {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWalletTransactionRepository extends Mock
    implements WalletTransactionRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockLabel extends Mock implements Label {}

class _FakeNewLabel extends Fake implements NewLabel {}

PayjoinReceiverModel _receiverModel({
  String id = 'pj1',
  String walletId = 'w1',
  String? originalTxId = 'orig-txid',
  String? proposalPsbt,
  String? txId,
  int? amountSat,
  // Defaults to already-elapsed (createdAt: 0) so isExpiryTimePassed is true
  // by default, matching most tests' expectations. Pass a large value to get
  // a not-yet-expired model instead (e.g. to exercise resume's live-session
  // branches).
  int expireAfterSec = 300,
}) {
  return PayjoinModel.receiver(
        id: id,
        address: 'tb1qtest',
        isTestnet: true,
        receiver: '[]',
        walletId: walletId,
        pjUri: 'bitcoin:tb1qtest?pj=https://payjo.in',
        maxFeeRateSatPerVb: BigInt.from(10),
        createdAt: 0,
        expireAfterSec: expireAfterSec,
        originalTxBytes: Uint8List.fromList([1, 2, 3]),
        originalTxId: originalTxId,
        proposalPsbt: proposalPsbt,
        txId: txId,
        amountSat: amountSat,
      )
      as PayjoinReceiverModel;
}

SettingsEntity _testSettings({int payjoinMinAmountSat = 10000}) =>
    SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
      payjoinMinAmountSat: payjoinMinAmountSat,
    );

Wallet _testWallet({String origin = 'w1'}) => Wallet(
  origin: origin,
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

WalletTransaction _testWalletTx({
  required String txId,
  required String walletId,
}) => WalletTransaction(
  walletId: walletId,
  network: Network.bitcoinMainnet,
  direction: WalletTransactionDirection.incoming,
  status: WalletTransactionStatus.confirmed,
  txId: txId,
  amountSat: 50000,
  feeSat: 500,
  vsize: 150,
  inputs: const [],
  outputs: const [],
  isRbf: false,
);

PayjoinSenderModel _senderModel({
  String uri = 'bitcoin:tb1qsender?pj=https://payjo.in',
  String walletId = 'w1',
  String originalTxId = 'sender-orig-txid',
  String? proposalPsbt,
}) {
  return PayjoinModel.sender(
        uri: uri,
        isTestnet: true,
        sender: '[]',
        walletId: walletId,
        originalPsbt: 'cHNidP8=',
        originalTxId: originalTxId,
        amountSat: 50000,
        createdAt: 0,
        expireAfterSec: 300,
        proposalPsbt: proposalPsbt,
      )
      as PayjoinSenderModel;
}

WalletUtxoModel _utxo(String txId, int vout) => WalletUtxoModel.bitcoin(
  txId: txId,
  vout: vout,
  amountSat: BigInt.from(50000),
  scriptPubkey: Uint8List(0),
  address: 'tb1qtest',
  isExternalKeyChain: false,
);

void main() {
  late _MockLocalPayjoinDatasource local;
  late _MockPdkPayjoinDatasource pdk;
  late _MockBdkBitcoinBlockchainDatasource blockchain;
  late _MockElectrumServersPort serversPort;
  late _MockLabelsFacade labels;
  late PayjoinRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(_FakeNewLabel());
    // PayjoinModel is sealed and can't be faked; a real instance serves as the
    // fallback value for any() matchers on PayjoinModel params (e.g. update).
    registerFallbackValue(_receiverModel());
    registerFallbackValue(
      ElectrumServerNetwork.fromEnvironment(isTestnet: true, isLiquid: false),
    );
    // Fallback for any()/wallet: any() matchers against
    // BdkWalletDatasource.signPsbt's `wallet` param in the _broadcastPsbt
    // real-signing-stack tests.
    registerFallbackValue(
      WalletModel.privateBdk(
            id: 'w1',
            scriptType: ScriptType.bip84,
            mnemonic: 'abandon',
            isTestnet: true,
          )
          as PrivateBdkWalletModel,
    );
  });

  setUp(() {
    local = _MockLocalPayjoinDatasource();
    pdk = _MockPdkPayjoinDatasource();
    blockchain = _MockBdkBitcoinBlockchainDatasource();
    serversPort = _MockElectrumServersPort();
    labels = _MockLabelsFacade();

    // The constructor wires up datasource stream listeners (resume is no
    // longer fired from the constructor — see resumePayjoinsOnStartup).
    // Stub the streams so construction is inert in the test.
    when(
      () => pdk.requestsForReceivers,
    ).thenAnswer((_) => const Stream.empty());
    when(() => pdk.proposalsForSenders).thenAnswer((_) => const Stream.empty());
    when(() => pdk.expiredPayjoins).thenAnswer((_) => const Stream.empty());
    when(
      () => local.fetchAll(onlyUnfinished: any(named: 'onlyUnfinished')),
    ).thenAnswer((_) async => const []);

    // A successful broadcast (the broadcast itself is not under test).
    when(
      () => serversPort.runWithFallback<void>(
        network: any(named: 'network'),
        operation: any(named: 'operation'),
      ),
    ).thenAnswer((_) async {});
    when(() => local.update(any())).thenAnswer((_) async {});
    when(
      () => labels.store(any()),
    ).thenAnswer((_) async => Ok<Label, LabelFailure>(_MockLabel()));

    repository = PayjoinRepositoryImpl(
      localPayjoinDatasource: local,
      pdkPayjoinDatasource: pdk,
      walletMetadataDatasource: _MockWalletMetadataDatasource(),
      seedDatasource: _MockSeedDatasource(),
      bdkWalletDatasource: _MockBdkWalletDatasource(),
      blockchainDatasource: blockchain,
      serversPort: serversPort,
      walletRepository: _MockWalletRepository.new,
      walletTransactionRepository: _MockWalletTransactionRepository.new,
      settingsRepository: _MockSettingsRepository(),
      labelsFacade: () => labels,
    );
  });

  // tryBroadcastOriginalTransaction is reached exclusively when no real
  // payjoin happened: declined below the anti-probing minimum, the
  // negotiation failed, or the session expired before a proposal was
  // exchanged. The transaction it broadcasts is byte-for-byte the caller's
  // own plain, single-party transaction, so it must never be tagged with the
  // payjoin system label — that label should only ever mean "this send
  // actually got CoinJoin-style privacy", which a plain fallback never did.
  group('tryBroadcastOriginalTransaction never labels the fallback tx', () {
    test('does not label a receiver fallback broadcast', () async {
      final model = _receiverModel(originalTxId: 'orig-txid');
      when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);

      final result = await repository.tryBroadcastOriginalTransaction(
        model.toEntity(),
      );

      expect(result, isNotNull);
      expect(result!.isCompleted, isTrue);
      verifyNever(() => labels.store(any()));
    });

    test('does not label when the original txid is unknown', () async {
      final model = _receiverModel(originalTxId: null);
      when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);

      await repository.tryBroadcastOriginalTransaction(model.toEntity());

      verifyNever(() => labels.store(any()));
    });

    test('clears a stale payjoin txId when completing a sender via the '
        'original-tx fallback', () async {
      // A sender's txId is set the moment a proposal is RECEIVED, before it
      // is signed/broadcast. When signing/broadcast then fails, the fallback
      // broadcasts the ORIGINAL transaction — keeping the stale txId around
      // would make SendCubit (txId ?? originalTxId) display and label a txid
      // that never reached the chain.
      //
      // isExpired: true makes this a legitimate manual retry through the
      // PUBLIC (guarded) entry point: the repository's own internal
      // fallback already tried once and ALSO failed to broadcast (that is
      // exactly how a sender session ends up isExpired with proposalPsbt
      // still set — see _processPayjoinProposal's terminal-failure branch),
      // so tryBroadcastOriginalTransaction's guard must let this one through
      // rather than treat the proposal as still "in flight".
      final model = _senderModel(
        originalTxId: 'sender-orig-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      ).copyWith(txId: 'stale-payjoin-txid', isExpired: true);
      when(() => local.fetchSender(model.uri)).thenAnswer((_) async => model);

      final result = await repository.tryBroadcastOriginalTransaction(
        model.toEntity(),
      );

      final persisted =
          verify(() => local.update(captureAny())).captured.single
              as PayjoinSenderModel;
      expect(persisted.isCompleted, isTrue);
      expect(persisted.txId, isNull);
      expect(persisted.originalTxId, 'sender-orig-txid');
      expect(result, isNotNull);
      expect((result! as PayjoinSender).txId, isNull);
    });

    test('does not label a sender fallback broadcast (#2246)', () async {
      final model = _senderModel(originalTxId: 'sender-orig-txid');
      when(() => local.fetchSender(model.uri)).thenAnswer((_) async => model);

      final result = await repository.tryBroadcastOriginalTransaction(
        model.toEntity(),
      );

      // The original transaction must actually be broadcast (the payment can't
      // silently never hit the chain when the receiver doesn't respond).
      verify(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).called(1);
      // And the session resolves as completed so the send flow can move on.
      expect(result, isNotNull);
      expect(result!.isCompleted, isTrue);
      verifyNever(() => labels.store(any()));
    });
  });

  group('tryBroadcastOriginalTransaction manual-call idempotency guard '
      '(the public entry point only — internal fallback callers bypass it '
      'via _broadcastOriginalTransaction)', () {
    test('refuses a receiver already completed, and returns its current '
        'state instead of re-broadcasting', () async {
      final model = _receiverModel(
        originalTxId: 'orig-txid',
      ).copyWith(isCompleted: true, txId: null);
      when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);

      final result = await repository.tryBroadcastOriginalTransaction(
        model.toEntity(),
      );

      expect(result, isNotNull);
      expect(result!.isCompleted, isTrue);
      verifyNever(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      );
    });

    test('refuses a receiver whose proposal was sent (proposed, not yet '
        'completed) — the sender owns it for as long as that takes, with '
        'no dead-end that would ever need a manual retry', () async {
      final model = _receiverModel(
        originalTxId: 'orig-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);

      await repository.tryBroadcastOriginalTransaction(model.toEntity());

      verifyNever(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      );
    });

    test('refuses a sender already completed via a real payjoin, and does '
        'NOT race it with the lower-fee original', () async {
      final model = _senderModel(
        originalTxId: 'sender-orig-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      ).copyWith(isCompleted: true, txId: 'real-payjoin-txid');
      when(() => local.fetchSender(model.uri)).thenAnswer((_) async => model);

      final result = await repository.tryBroadcastOriginalTransaction(
        model.toEntity(),
      );

      expect(result, isNotNull);
      expect((result! as PayjoinSender).txId, 'real-payjoin-txid');
      verifyNever(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      );
    });

    test('refuses a sender whose proposal is still being processed '
        '(proposalPsbt set, not yet completed or expired)', () async {
      final model = _senderModel(
        originalTxId: 'sender-orig-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      when(() => local.fetchSender(model.uri)).thenAnswer((_) async => model);

      await repository.tryBroadcastOriginalTransaction(model.toEntity());

      verifyNever(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      );
    });

    test('allows a sender manual retry once its OWN internal fallback also '
        'gave up (isExpired, proposalPsbt still set) — no dead-end left, so '
        'this must not be permanently blocked', () async {
      final model = _senderModel(
        originalTxId: 'sender-orig-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      ).copyWith(isExpired: true);
      when(() => local.fetchSender(model.uri)).thenAnswer((_) async => model);

      final result = await repository.tryBroadcastOriginalTransaction(
        model.toEntity(),
      );

      verify(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).called(1);
      expect(result, isNotNull);
      expect(result!.isCompleted, isTrue);
    });

    test('allows a receiver or sender manual retry while no proposal has '
        'ever been received (waiting)', () async {
      final receiverModel = _receiverModel(originalTxId: 'orig-txid');
      when(
        () => local.fetchReceiver('pj1'),
      ).thenAnswer((_) async => receiverModel);

      final result = await repository.tryBroadcastOriginalTransaction(
        receiverModel.toEntity(),
      );

      verify(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).called(1);
      expect(result, isNotNull);
      expect(result!.isCompleted, isTrue);
    });
  });

  group('syncs the wallet after WE broadcast a transaction', () {
    // Without this, the wallet balance/tx list only picked up a broadcast
    // this repository itself just made once some unrelated sync happened to
    // run — the same staleness class of gap _watchForBroadcast's active poll
    // fixes for the receiver's own detection of the SENDER's broadcast.
    late _MockWalletRepository walletRepo;

    setUp(() {
      walletRepo = _MockWalletRepository();
      when(
        () => walletRepo.getWallet(any(), sync: any(named: 'sync')),
      ).thenAnswer((_) async => null);
      when(
        () => walletRepo.walletSyncFinishedStream,
      ).thenAnswer((_) => const Stream.empty());
    });

    test('tryBroadcastOriginalTransaction (receiver fallback) forces a '
        'synced wallet lookup after a successful broadcast', () async {
      final repo = PayjoinRepositoryImpl(
        localPayjoinDatasource: local,
        pdkPayjoinDatasource: pdk,
        walletMetadataDatasource: _MockWalletMetadataDatasource(),
        seedDatasource: _MockSeedDatasource(),
        bdkWalletDatasource: _MockBdkWalletDatasource(),
        blockchainDatasource: blockchain,
        serversPort: serversPort,
        walletRepository: () => walletRepo,
        walletTransactionRepository: _MockWalletTransactionRepository.new,
        settingsRepository: _MockSettingsRepository(),
        labelsFacade: () => labels,
      );
      final model = _receiverModel(walletId: 'w1', originalTxId: 'orig-txid');
      when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);

      await repo.tryBroadcastOriginalTransaction(model.toEntity());
      // The sync is deliberately fire-and-forget (unawaited); give its
      // Future(() => ...) wrapper a tick to run before verifying.
      await Future<void>.delayed(Duration.zero);

      verify(() => walletRepo.getWallet('w1', sync: true)).called(1);
    });

    test('tryBroadcastOriginalTransaction (sender fallback) forces a synced '
        'wallet lookup after a successful broadcast', () async {
      final repo = PayjoinRepositoryImpl(
        localPayjoinDatasource: local,
        pdkPayjoinDatasource: pdk,
        walletMetadataDatasource: _MockWalletMetadataDatasource(),
        seedDatasource: _MockSeedDatasource(),
        bdkWalletDatasource: _MockBdkWalletDatasource(),
        blockchainDatasource: blockchain,
        serversPort: serversPort,
        walletRepository: () => walletRepo,
        walletTransactionRepository: _MockWalletTransactionRepository.new,
        settingsRepository: _MockSettingsRepository(),
        labelsFacade: () => labels,
      );
      final model = _senderModel(
        walletId: 'w1',
        originalTxId: 'sender-orig-txid',
      );
      when(() => local.fetchSender(model.uri)).thenAnswer((_) async => model);

      await repo.tryBroadcastOriginalTransaction(model.toEntity());
      await Future<void>.delayed(Duration.zero);

      verify(() => walletRepo.getWallet('w1', sync: true)).called(1);
    });

    test('a sync failure is swallowed and does not affect the already-'
        'successful broadcast result', () async {
      when(
        () => walletRepo.getWallet(any(), sync: any(named: 'sync')),
      ).thenThrow(Exception('no network'));
      final repo = PayjoinRepositoryImpl(
        localPayjoinDatasource: local,
        pdkPayjoinDatasource: pdk,
        walletMetadataDatasource: _MockWalletMetadataDatasource(),
        seedDatasource: _MockSeedDatasource(),
        bdkWalletDatasource: _MockBdkWalletDatasource(),
        blockchainDatasource: blockchain,
        serversPort: serversPort,
        walletRepository: () => walletRepo,
        walletTransactionRepository: _MockWalletTransactionRepository.new,
        settingsRepository: _MockSettingsRepository(),
        labelsFacade: () => labels,
      );
      final model = _receiverModel(walletId: 'w1', originalTxId: 'orig-txid');
      when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);

      final result = await repo.tryBroadcastOriginalTransaction(
        model.toEntity(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(result, isNotNull);
      expect(result!.isCompleted, isTrue);
    });

    test('_broadcastPsbt (sender, real payjoin) forces a synced wallet '
        'lookup after broadcasting the finalized proposal', () async {
      final proposalController =
          StreamController<PayjoinSenderModel>.broadcast();
      addTearDown(proposalController.close);
      when(
        () => pdk.proposalsForSenders,
      ).thenAnswer((_) => proposalController.stream);

      // Full signing stack so _processPayjoinProposal reaches _broadcastPsbt
      // instead of falling into the original-tx fallback.
      final walletMetadata = _MockWalletMetadataDatasource();
      final seed = _MockSeedDatasource();
      final bdkWallet = _MockBdkWalletDatasource();
      when(() => walletMetadata.fetch('w1')).thenAnswer(
        (_) async => const WalletMetadataModel(
          id: 'wpkh([00000000/84h/1h/0h])',
          masterFingerprint: '00000000',
          xpubFingerprint: '11111111',
          isEncryptedVaultTested: false,
          isPhysicalBackupTested: false,
          xpub: '',
          externalPublicDescriptor: '',
          internalPublicDescriptor: '',
          signer: Signer.local,
          isDefault: true,
        ),
      );
      when(() => seed.get('00000000')).thenAnswer(
        (_) async =>
            const SeedModel.mnemonic(
                  mnemonicWords: [
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'about',
                  ],
                )
                as MnemonicSeedModel,
      );
      when(
        () => bdkWallet.signPsbt(any(), wallet: any(named: 'wallet')),
      ).thenAnswer((_) async => 'signed-psbt');

      final model = _senderModel(
        walletId: 'w1',
        originalTxId: 'sender-orig-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      ).copyWith(txId: 'payjoin-txid');
      when(() => local.fetchSender(model.uri)).thenAnswer((_) async => model);

      // Constructing it wires the datasource stream subscriptions that drive
      // this test; nothing further is called on it directly.
      PayjoinRepositoryImpl(
        localPayjoinDatasource: local,
        pdkPayjoinDatasource: pdk,
        walletMetadataDatasource: walletMetadata,
        seedDatasource: seed,
        bdkWalletDatasource: bdkWallet,
        blockchainDatasource: blockchain,
        serversPort: serversPort,
        walletRepository: () => walletRepo,
        walletTransactionRepository: _MockWalletTransactionRepository.new,
        settingsRepository: _MockSettingsRepository(),
        labelsFacade: () => labels,
      );

      proposalController.add(model);
      // Two ticks: the first drains the stream-delivery + signing/broadcast
      // await chain (which schedules _syncWalletAfterBroadcast's own
      // Future(() => ...) timer along the way); the second lets that timer
      // itself fire. A single tick races it against this delay's own timer,
      // registered before the stream ever delivers its event.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(() => walletRepo.getWallet('w1', sync: true)).called(1);
    });
  });

  group('_processExpiredPayjoin sender terminal emission (#2246)', () {
    // These drive the expiredPayjoins stream directly to exercise the
    // repository's terminal-emission semantics on the send flow.
    late StreamController<PayjoinModel> expiredController;

    setUp(() {
      expiredController = StreamController<PayjoinModel>.broadcast();
      when(
        () => pdk.expiredPayjoins,
      ).thenAnswer((_) => expiredController.stream);
      repository = PayjoinRepositoryImpl(
        localPayjoinDatasource: local,
        pdkPayjoinDatasource: pdk,
        walletMetadataDatasource: _MockWalletMetadataDatasource(),
        seedDatasource: _MockSeedDatasource(),
        bdkWalletDatasource: _MockBdkWalletDatasource(),
        blockchainDatasource: blockchain,
        serversPort: serversPort,
        walletRepository: _MockWalletRepository.new,
        walletTransactionRepository: _MockWalletTransactionRepository.new,
        settingsRepository: _MockSettingsRepository(),
        labelsFacade: () => labels,
      );
    });

    tearDown(() => expiredController.close());

    test('emits only the completed result (no interim expired) when the '
        'fallback broadcast succeeds', () async {
      final model = _senderModel(originalTxId: 'sender-orig-txid');
      when(() => local.fetchSender(model.uri)).thenAnswer((_) async => model);

      final emitted = <Payjoin>[];
      final sub = repository.payjoinStream.listen(emitted.add);

      expiredController.add(model.copyWith(isExpired: true));
      await Future<void>.delayed(Duration.zero);

      // Exactly one terminal event, and it is completed (not the interim
      // expired one that would race the success on the send flow).
      expect(emitted, hasLength(1));
      expect(emitted.single.isCompleted, isTrue);
      await sub.cancel();
    });

    test('emits the expired entity when the fallback broadcast fails so the '
        'send flow does not hang', () async {
      final model = _senderModel(originalTxId: 'sender-orig-txid');
      when(() => local.fetchSender(model.uri)).thenAnswer((_) async => model);
      // Make the broadcast fail -> tryBroadcastOriginalTransaction returns null.
      when(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).thenThrow(Exception('broadcast failed'));

      final emitted = <Payjoin>[];
      final sub = repository.payjoinStream.listen(emitted.add);

      expiredController.add(model.copyWith(isExpired: true));
      await Future<void>.delayed(Duration.zero);

      // A terminal expired event is still emitted so listeners aren't left
      // hanging on "coordinating".
      expect(emitted, hasLength(1));
      expect(emitted.single.isExpired, isTrue);
      await sub.cancel();
    });
  });

  group('_processPayjoinProposal terminal emission on broadcast failure '
      '(#2246)', () {
    // These drive the proposalsForSenders stream directly: a received
    // proposal whose signing/broadcast fails must still produce a terminal
    // event, because by the time a proposal arrives the poll timer that
    // would otherwise raise an expiry is already cancelled — nothing else
    // will ever emit for this session again.
    late StreamController<PayjoinSenderModel> proposalController;
    late _MockWalletMetadataDatasource walletMetadata;

    setUp(() {
      proposalController = StreamController<PayjoinSenderModel>.broadcast();
      walletMetadata = _MockWalletMetadataDatasource();
      when(
        () => pdk.proposalsForSenders,
      ).thenAnswer((_) => proposalController.stream);
      // _loadWallet throws when metadata is missing — the simplest way to
      // drive _processPayjoinProposal's catch without mocking a full signing
      // stack.
      when(() => walletMetadata.fetch(any())).thenAnswer((_) async => null);
      repository = PayjoinRepositoryImpl(
        localPayjoinDatasource: local,
        pdkPayjoinDatasource: pdk,
        walletMetadataDatasource: walletMetadata,
        seedDatasource: _MockSeedDatasource(),
        bdkWalletDatasource: _MockBdkWalletDatasource(),
        blockchainDatasource: blockchain,
        serversPort: serversPort,
        walletRepository: _MockWalletRepository.new,
        walletTransactionRepository: _MockWalletTransactionRepository.new,
        settingsRepository: _MockSettingsRepository(),
        labelsFacade: () => labels,
      );
    });

    tearDown(() => proposalController.close());

    test('falls back to broadcasting the original psbt and completes when '
        'signing/broadcasting the proposal fails', () async {
      final model = _senderModel(
        originalTxId: 'sender-orig-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      when(() => local.fetchSender(model.uri)).thenAnswer((_) async => model);

      final emitted = <Payjoin>[];
      final sub = repository.payjoinStream.listen(emitted.add);

      proposalController.add(model);
      await Future<void>.delayed(Duration.zero);

      // Two events: the raw "proposal received" one, then the fallback's
      // completed terminal one (the original transaction still got
      // broadcast, so the send flow can resolve to success).
      expect(emitted, hasLength(2));
      expect(emitted.last.isCompleted, isTrue);
      await sub.cancel();
    });

    test('marks the session terminally failed when both the proposal and '
        'the original-transaction fallback fail to broadcast', () async {
      final model = _senderModel(
        originalTxId: 'sender-orig-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      when(() => local.fetchSender(model.uri)).thenAnswer((_) async => model);
      when(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).thenThrow(Exception('broadcast failed'));

      final emitted = <Payjoin>[];
      final sub = repository.payjoinStream.listen(emitted.add);

      proposalController.add(model);
      await Future<void>.delayed(Duration.zero);

      // Terminal failure, not silence: the send flow must never hang forever
      // waiting for an event that will never arrive.
      expect(emitted, hasLength(2));
      expect(emitted.last.isExpired, isTrue);
      await sub.cancel();
    });
  });

  group('PayjoinRepositoryImpl.filterAvailableUtxos', () {
    test('excludes locked UTXOs', () {
      final unspent = [_utxo('a', 0), _utxo('b', 1)];
      final locked = [(txId: 'a', vout: 0)];

      final result = PayjoinRepositoryImpl.filterAvailableUtxos(
        unspent,
        locked,
        const {},
      );

      expect(result, hasLength(1));
      expect(result.single.txId, 'b');
    });

    test('drops non-bitcoin (liquid) UTXOs', () {
      final unspent = [
        _utxo('a', 0),
        WalletUtxoModel.liquid(
          txId: 'liquid',
          vout: 0,
          amountSat: BigInt.from(50000),
          scriptPubkey: 'x',
          standardAddress: 'x',
          confidentialAddress: 'x',
        ),
      ];

      final result = PayjoinRepositoryImpl.filterAvailableUtxos(
        unspent,
        const [],
        const {},
      );

      expect(result, hasLength(1));
      expect(result.single.txId, 'a');
    });

    test('prefers already-exposed UTXOs first (reuse over fresh)', () {
      final unspent = [
        _utxo('fresh', 0),
        _utxo('exposed', 1),
        _utxo('fresh2', 2),
      ];
      final exposed = {'exposed:1'};

      final result = PayjoinRepositoryImpl.filterAvailableUtxos(
        unspent,
        const [],
        exposed,
      );

      // The exposed UTXO must sort ahead of the fresh ones so it is the
      // preferred contribution.
      expect(result.first.txId, 'exposed');
      expect(result, hasLength(3));
    });

    test('keeps all fresh UTXOs when none are exposed', () {
      final unspent = [_utxo('a', 0), _utxo('b', 1)];

      final result = PayjoinRepositoryImpl.filterAvailableUtxos(
        unspent,
        const [],
        const {},
      );

      expect(result.map((e) => e.txId), containsAll(['a', 'b']));
    });

    test('an exposed UTXO that is also locked is still excluded', () {
      final unspent = [_utxo('exposed', 0)];

      final result = PayjoinRepositoryImpl.filterAvailableUtxos(
        unspent,
        [(txId: 'exposed', vout: 0)],
        {'exposed:0'},
      );

      expect(result, isEmpty);
    });
  });

  group('PayjoinRepositoryImpl.isBelowPayjoinMinimum', () {
    test('is true when the received amount is strictly below the minimum', () {
      expect(
        PayjoinRepositoryImpl.isBelowPayjoinMinimum(
          amountSat: 9999,
          minAmountSat: 10000,
        ),
        isTrue,
      );
    });

    test('is false at exactly the minimum (boundary is inclusive)', () {
      expect(
        PayjoinRepositoryImpl.isBelowPayjoinMinimum(
          amountSat: 10000,
          minAmountSat: 10000,
        ),
        isFalse,
      );
    });

    test('is false above the minimum', () {
      expect(
        PayjoinRepositoryImpl.isBelowPayjoinMinimum(
          amountSat: 50000,
          minAmountSat: 10000,
        ),
        isFalse,
      );
    });

    test('a null (unknown) amount is never treated as below-minimum', () {
      expect(
        PayjoinRepositoryImpl.isBelowPayjoinMinimum(
          amountSat: null,
          minAmountSat: 10000,
        ),
        isFalse,
      );
    });
  });

  group('PayjoinRepositoryImpl.retryOnTransient', () {
    test('returns the result on first success without retrying', () async {
      var calls = 0;
      final result = await PayjoinRepositoryImpl.retryOnTransient(() async {
        calls++;
        return 'ok';
      }, delay: Duration.zero);

      expect(result, 'ok');
      expect(calls, 1);
    });

    test('retries a transient relay failure then succeeds', () async {
      var calls = 0;
      final result = await PayjoinRepositoryImpl.retryOnTransient(
        () async {
          calls++;
          if (calls < 3) {
            throw PayjoinNotFoundException('relay blip');
          }
          return 'ok';
        },
        maxAttempts: 3,
        delay: Duration.zero,
      );

      expect(result, 'ok');
      expect(calls, 3);
    });

    test('rethrows after exhausting maxAttempts on persistent transient '
        'failure', () async {
      var calls = 0;
      await expectLater(
        PayjoinRepositoryImpl.retryOnTransient(
          () async {
            calls++;
            throw PayjoinNotFoundException('always down');
          },
          maxAttempts: 3,
          delay: Duration.zero,
        ),
        throwsA(isA<PayjoinNotFoundException>()),
      );
      expect(calls, 3);
    });

    test(
      'rethrows a non-transient error immediately without retrying',
      () async {
        var calls = 0;
        await expectLater(
          PayjoinRepositoryImpl.retryOnTransient(
            () async {
              calls++;
              throw StateError('not transient');
            },
            maxAttempts: 3,
            delay: Duration.zero,
          ),
          throwsA(isA<StateError>()),
        );
        // Non-transient errors must not be retried — the caller's fallback
        // should fire without waiting out the retry budget.
        expect(calls, 1);
      },
    );
  });

  group('resumePayjoinsOnStartup', () {
    test(
      'one session failing to resume does not stop the others from resuming',
      () async {
        // Both models are already past expiry by construction (createdAt: 0,
        //  expireAfterSec: 300), and both have a proposal already sent, so
        //  _resumeOne routes them straight to _processExpiredPayjoin's
        //  persist-and-emit else branch (no broadcast attempted).
        final bad = _receiverModel(
          id: 'bad',
          originalTxId: 'bad-orig',
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        );
        final ok = _receiverModel(
          id: 'ok',
          originalTxId: 'ok-orig',
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        );
        when(
          () => local.fetchAll(onlyUnfinished: true),
        ).thenAnswer((_) async => [bad, ok]);
        // "bad"'s persist throws (e.g. a transient DB failure); "ok"'s must
        //  still go through despite "bad" throwing first in the loop.
        when(
          () => local.update(
            any(that: predicate<PayjoinModel>((m) => m.id == 'bad')),
          ),
        ).thenThrow(Exception('boom'));
        when(
          () => local.update(
            any(that: predicate<PayjoinModel>((m) => m.id == 'ok')),
          ),
        ).thenAnswer((_) async {});

        final emitted = <Payjoin>[];
        final sub = repository.payjoinStream.listen(emitted.add);

        await repository.resumePayjoinsOnStartup();
        await Future<void>.delayed(Duration.zero);

        // "ok" was still resumed and emitted, proving the per-session
        //  try/catch stopped "bad"'s failure from aborting the whole loop.
        expect(emitted, hasLength(1));
        expect(emitted.single.id, 'ok');
        await sub.cancel();
      },
    );
  });

  group(
    '_watchForBroadcast survives a receiver session expiring (H2 follow-up)',
    () {
      test('a proposal-sent receiver session that expires before the tx is '
          'seen still completes once the tx appears on-chain', () async {
        final walletRepo = _MockWalletRepository();
        final walletTxRepo = _MockWalletTransactionRepository();
        final syncController = StreamController<Wallet>.broadcast();
        final expiredController = StreamController<PayjoinModel>.broadcast();
        addTearDown(() async {
          await syncController.close();
          await expiredController.close();
        });

        when(
          () => pdk.expiredPayjoins,
        ).thenAnswer((_) => expiredController.stream);
        when(
          () => walletRepo.walletSyncFinishedStream,
        ).thenAnswer((_) => syncController.stream);

        // Not yet expired at resume time, so _resumeOne takes the
        //  "proposal already sent, watch for broadcast" branch.
        final model = _receiverModel(
          id: 'pj1',
          walletId: 'w1',
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
          txId: 'payjoin-txid',
          expireAfterSec: 9999999999,
        );
        when(
          () => local.fetchAll(onlyUnfinished: true),
        ).thenAnswer((_) async => [model]);
        when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);

        // The tx isn't visible yet the first time it's looked up.
        var txSeen = false;
        when(
          () =>
              walletTxRepo.getWalletTransaction('payjoin-txid', walletId: 'w1'),
        ).thenAnswer(
          (_) async => txSeen
              ? _testWalletTx(txId: 'payjoin-txid', walletId: 'w1')
              : null,
        );

        final repo = PayjoinRepositoryImpl(
          localPayjoinDatasource: local,
          pdkPayjoinDatasource: pdk,
          walletMetadataDatasource: _MockWalletMetadataDatasource(),
          seedDatasource: _MockSeedDatasource(),
          bdkWalletDatasource: _MockBdkWalletDatasource(),
          blockchainDatasource: blockchain,
          serversPort: serversPort,
          walletRepository: () => walletRepo,
          walletTransactionRepository: () => walletTxRepo,
          settingsRepository: _MockSettingsRepository(),
          labelsFacade: () => labels,
        );

        // Arms _watchForBroadcast for this session.
        await repo.resumePayjoinsOnStartup();

        final emitted = <Payjoin>[];
        final sub = repo.payjoinStream.listen(emitted.add);

        // The session's own expiry fires live (proposalPsbt != null routes
        //  to the `else` branch: persisted as expired, but the broadcast
        //  watcher armed above is deliberately NOT stopped).
        expiredController.add(model.copyWith(isExpired: true));
        await Future<void>.delayed(Duration.zero);

        expect(emitted, hasLength(1));
        expect(emitted.single.isExpired, isTrue);

        // The payjoin transaction the sender broadcast now appears
        //  on-chain, on the next wallet sync.
        txSeen = true;
        syncController.add(_testWallet(origin: 'w1'));
        await Future<void>.delayed(Duration.zero);

        // The session completes despite having been marked expired.
        expect(emitted, hasLength(2));
        expect(emitted.last.isCompleted, isTrue);
        await sub.cancel();
      });
    },
  );

  group('_watchForBroadcast active polling', () {
    // The passive watcher only reacts to walletSyncFinishedStream, i.e. to
    // syncs triggered by something else entirely. Observed live: a receiver
    // stuck on "payjoin in progress" for ~9 minutes after the sender had
    // already broadcast the payjoin tx, because nothing happened to sync the
    // wallet. The active poll forces bounded sync'd lookups itself.
    late _MockWalletRepository walletRepo;
    late _MockWalletTransactionRepository walletTxRepo;
    late StreamController<Wallet> syncController;

    setUp(() {
      walletRepo = _MockWalletRepository();
      walletTxRepo = _MockWalletTransactionRepository();
      syncController = StreamController<Wallet>.broadcast();
      when(
        () => walletRepo.walletSyncFinishedStream,
      ).thenAnswer((_) => syncController.stream);

      // A not-yet-expired proposal-sent receiver session, so resume arms
      // _watchForBroadcast.
      final model = _receiverModel(
        id: 'pj1',
        walletId: 'w1',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        txId: 'payjoin-txid',
        expireAfterSec: 9999999999,
      );
      when(
        () => local.fetchAll(onlyUnfinished: true),
      ).thenAnswer((_) async => [model]);
      when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);
    });

    tearDown(() => syncController.close());

    PayjoinRepositoryImpl buildRepo() => PayjoinRepositoryImpl(
      localPayjoinDatasource: local,
      pdkPayjoinDatasource: pdk,
      walletMetadataDatasource: _MockWalletMetadataDatasource(),
      seedDatasource: _MockSeedDatasource(),
      bdkWalletDatasource: _MockBdkWalletDatasource(),
      blockchainDatasource: blockchain,
      serversPort: serversPort,
      walletRepository: () => walletRepo,
      walletTransactionRepository: () => walletTxRepo,
      settingsRepository: _MockSettingsRepository(),
      labelsFacade: () => labels,
    );

    test('completes the session via a forced-sync lookup when no wallet sync '
        'ever happens, then stops polling', () {
      fakeAsync((async) {
        var txSeen = false;
        when(
          () => walletTxRepo.getWalletTransaction(
            'payjoin-txid',
            walletId: 'w1',
            sync: true,
          ),
        ).thenAnswer(
          (_) async => txSeen
              ? _testWalletTx(txId: 'payjoin-txid', walletId: 'w1')
              : null,
        );

        final repo = buildRepo();
        unawaited(repo.resumePayjoinsOnStartup());
        async.flushMicrotasks();

        final emitted = <Payjoin>[];
        repo.payjoinStream.listen(emitted.add);

        // First poll fires after the initial delay; the tx isn't visible yet.
        async.elapse(PayjoinRepositoryImpl.broadcastPollInitialDelay);
        expect(emitted, isEmpty);

        // The sender broadcasts; the next (backed-off) poll finds the tx and
        // completes the session — no walletSyncFinishedStream event ever
        // fired in this entire test.
        txSeen = true;
        async.elapse(PayjoinRepositoryImpl.broadcastPollInitialDelay * 2);
        async.flushMicrotasks();

        expect(emitted, hasLength(1));
        expect(emitted.single.isCompleted, isTrue);
        verify(
          () => walletTxRepo.getWalletTransaction(
            'payjoin-txid',
            walletId: 'w1',
            sync: true,
          ),
        ).called(2);

        // Completion is one-shot: no further forced syncs afterwards.
        async.elapse(const Duration(hours: 2));
        verifyNever(
          () => walletTxRepo.getWalletTransaction(
            'payjoin-txid',
            walletId: 'w1',
            sync: true,
          ),
        );
      });
    });

    test('gives up active polling after the attempt budget but the passive '
        'sync-driven watcher still completes a very late broadcast', () {
      fakeAsync((async) {
        var txSeen = false;
        // Active polls never see the tx (it lands hours later).
        when(
          () => walletTxRepo.getWalletTransaction(
            'payjoin-txid',
            walletId: 'w1',
            sync: true,
          ),
        ).thenAnswer((_) async => null);
        // Passive (local, non-forced) lookups see it once txSeen flips.
        when(
          () =>
              walletTxRepo.getWalletTransaction('payjoin-txid', walletId: 'w1'),
        ).thenAnswer(
          (_) async => txSeen
              ? _testWalletTx(txId: 'payjoin-txid', walletId: 'w1')
              : null,
        );

        final repo = buildRepo();
        unawaited(repo.resumePayjoinsOnStartup());
        async.flushMicrotasks();

        final emitted = <Payjoin>[];
        repo.payjoinStream.listen(emitted.add);

        // Way past the whole active-poll schedule: exactly maxAttempts
        // forced syncs ran, then the poll chain stopped rescheduling.
        async.elapse(const Duration(hours: 3));
        verify(
          () => walletTxRepo.getWalletTransaction(
            'payjoin-txid',
            walletId: 'w1',
            sync: true,
          ),
        ).called(PayjoinRepositoryImpl.broadcastPollMaxAttempts);
        expect(emitted, isEmpty);

        // The payjoin tx finally lands and some organic sync of this wallet
        // finishes: the passive watcher completes the session.
        txSeen = true;
        syncController.add(_testWallet(origin: 'w1'));
        async.flushMicrotasks();

        expect(emitted, hasLength(1));
        expect(emitted.single.isCompleted, isTrue);
      });
    });
  });

  group('payjoin labeling on the real completion paths', () {
    // The payjoin system label must mean "this payment actually got
    // CoinJoin-style privacy". The fallback path never labels (covered
    // above); these cover the two paths that MUST label: the receiver seeing
    // the payjoin tx on-chain and the sender broadcasting the finalized
    // proposal.
    test('labels the receiver payjoin tx once it is seen on-chain '
        '(_onPayjoinTransactionSeen)', () async {
      final walletRepo = _MockWalletRepository();
      final walletTxRepo = _MockWalletTransactionRepository();
      final syncController = StreamController<Wallet>.broadcast();
      addTearDown(syncController.close);
      when(
        () => walletRepo.walletSyncFinishedStream,
      ).thenAnswer((_) => syncController.stream);

      final model = _receiverModel(
        id: 'pj1',
        walletId: 'w1',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        txId: 'payjoin-txid',
        expireAfterSec: 9999999999,
      );
      when(
        () => local.fetchAll(onlyUnfinished: true),
      ).thenAnswer((_) async => [model]);
      when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);
      when(
        () => walletTxRepo.getWalletTransaction('payjoin-txid', walletId: 'w1'),
      ).thenAnswer(
        (_) async => _testWalletTx(txId: 'payjoin-txid', walletId: 'w1'),
      );

      final repo = PayjoinRepositoryImpl(
        localPayjoinDatasource: local,
        pdkPayjoinDatasource: pdk,
        walletMetadataDatasource: _MockWalletMetadataDatasource(),
        seedDatasource: _MockSeedDatasource(),
        bdkWalletDatasource: _MockBdkWalletDatasource(),
        blockchainDatasource: blockchain,
        serversPort: serversPort,
        walletRepository: () => walletRepo,
        walletTransactionRepository: () => walletTxRepo,
        settingsRepository: _MockSettingsRepository(),
        labelsFacade: () => labels,
      );
      await repo.resumePayjoinsOnStartup();

      syncController.add(_testWallet(origin: 'w1'));
      await Future<void>.delayed(Duration.zero);

      final stored =
          verify(() => labels.store(captureAny())).captured.single as NewLabel;
      expect(stored.type, LabelType.transaction);
      expect(stored.reference, 'payjoin-txid');
      expect(stored.label, LabelSystem.payjoin.label);
      expect(stored.origin, 'w1');
    });

    test('labels the sender payjoin tx after broadcasting the finalized '
        'proposal (_broadcastPsbt)', () async {
      final proposalController =
          StreamController<PayjoinSenderModel>.broadcast();
      addTearDown(proposalController.close);
      when(
        () => pdk.proposalsForSenders,
      ).thenAnswer((_) => proposalController.stream);

      // Full signing stack so _processPayjoinProposal reaches _broadcastPsbt
      // instead of falling into the original-tx fallback.
      final walletMetadata = _MockWalletMetadataDatasource();
      final seed = _MockSeedDatasource();
      final bdkWallet = _MockBdkWalletDatasource();
      when(() => walletMetadata.fetch('w1')).thenAnswer(
        (_) async => const WalletMetadataModel(
          // A parseable origin id: bip84, bitcoin testnet, account 0.
          id: 'wpkh([00000000/84h/1h/0h])',
          masterFingerprint: '00000000',
          xpubFingerprint: '11111111',
          isEncryptedVaultTested: false,
          isPhysicalBackupTested: false,
          xpub: '',
          externalPublicDescriptor: '',
          internalPublicDescriptor: '',
          signer: Signer.local,
          isDefault: true,
        ),
      );
      when(() => seed.get('00000000')).thenAnswer(
        (_) async =>
            const SeedModel.mnemonic(
                  mnemonicWords: [
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'abandon',
                    'about',
                  ],
                )
                as MnemonicSeedModel,
      );
      when(
        () => bdkWallet.signPsbt(any(), wallet: any(named: 'wallet')),
      ).thenAnswer((_) async => 'signed-psbt');

      // txId was set when the proposal was received (before broadcast).
      final model = _senderModel(
        originalTxId: 'sender-orig-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      ).copyWith(txId: 'payjoin-txid');
      when(() => local.fetchSender(model.uri)).thenAnswer((_) async => model);

      final repo = PayjoinRepositoryImpl(
        localPayjoinDatasource: local,
        pdkPayjoinDatasource: pdk,
        walletMetadataDatasource: walletMetadata,
        seedDatasource: seed,
        bdkWalletDatasource: bdkWallet,
        blockchainDatasource: blockchain,
        serversPort: serversPort,
        walletRepository: _MockWalletRepository.new,
        walletTransactionRepository: _MockWalletTransactionRepository.new,
        settingsRepository: _MockSettingsRepository(),
        labelsFacade: () => labels,
      );

      final emitted = <Payjoin>[];
      final sub = repo.payjoinStream.listen(emitted.add);
      addTearDown(sub.cancel);

      proposalController.add(model);
      await Future<void>.delayed(Duration.zero);

      // The session completed through the REAL payjoin broadcast, keeping
      // the payjoin txid (a fallback would have cleared it).
      expect(emitted.last.isCompleted, isTrue);
      expect((emitted.last as PayjoinSender).txId, 'payjoin-txid');

      final stored =
          verify(() => labels.store(captureAny())).captured.single as NewLabel;
      expect(stored.type, LabelType.transaction);
      expect(stored.reference, 'payjoin-txid');
      expect(stored.label, LabelSystem.payjoin.label);
      expect(stored.origin, 'w1');
    });
  });

  group('_watchForFallback (the counterparty fell back independently)', () {
    // Both sides hold their own copy of the original transaction and can
    // each independently decide to broadcast it. Before this watch existed,
    // only the side that actually broadcast it persisted isCompleted — the
    // OTHER side had no way to find out and just kept waiting on its own
    // session (a live negotiation, or its own not-yet-fired expiry timer).
    test('a sender still waiting for a proposal completes once the original '
        'transaction appears in its wallet — the receiver broadcast it '
        'independently (e.g. declined below the anti-probing minimum) and '
        'the sender would otherwise have waited out its own full expiry '
        'with no signal the payment had already landed', () async {
      final walletRepo = _MockWalletRepository();
      final walletTxRepo = _MockWalletTransactionRepository();
      final syncController = StreamController<Wallet>.broadcast();
      addTearDown(syncController.close);
      when(
        () => walletRepo.walletSyncFinishedStream,
      ).thenAnswer((_) => syncController.stream);

      // Not yet expired, no proposal received yet: _resumeOne's sender
      // branch arms _watchForFallback unconditionally (originalTxId is
      // always known for a sender, set at session creation).
      final model = _senderModel(
        originalTxId: 'sender-orig-txid',
      ).copyWith(expireAfterSec: 9999999999);
      when(
        () => local.fetchAll(onlyUnfinished: true),
      ).thenAnswer((_) async => [model]);
      // _onOriginalTransactionSeen always tries the receiver table first.
      when(
        () => local.fetchReceiver('bitcoin:tb1qsender?pj=https://payjo.in'),
      ).thenAnswer((_) async => null);
      when(
        () => local.fetchSender('bitcoin:tb1qsender?pj=https://payjo.in'),
      ).thenAnswer((_) async => model);

      // The original transaction is now visible in the sender's own
      // wallet — broadcast by the receiver, not by this device.
      when(
        () => walletTxRepo.getWalletTransaction(
          'sender-orig-txid',
          walletId: 'w1',
        ),
      ).thenAnswer(
        (_) async => _testWalletTx(txId: 'sender-orig-txid', walletId: 'w1'),
      );

      final repo = PayjoinRepositoryImpl(
        localPayjoinDatasource: local,
        pdkPayjoinDatasource: pdk,
        walletMetadataDatasource: _MockWalletMetadataDatasource(),
        seedDatasource: _MockSeedDatasource(),
        bdkWalletDatasource: _MockBdkWalletDatasource(),
        blockchainDatasource: blockchain,
        serversPort: serversPort,
        walletRepository: () => walletRepo,
        walletTransactionRepository: () => walletTxRepo,
        settingsRepository: _MockSettingsRepository(),
        labelsFacade: () => labels,
      );

      await repo.resumePayjoinsOnStartup();

      final emitted = <Payjoin>[];
      final sub = repo.payjoinStream.listen(emitted.add);

      // Some unrelated wallet sync finishes — the same passive mechanism
      // a sender already relies on to notice its own successful payjoin
      // broadcast.
      syncController.add(_testWallet(origin: 'w1'));
      await Future<void>.delayed(Duration.zero);

      expect(emitted, hasLength(1));
      expect(emitted.single.status, PayjoinStatus.aborted);
      expect(emitted.single.isCompleted, isTrue);
      expect((emitted.single as PayjoinSender).txId, isNull);
      await sub.cancel();
    });

    test(
      'idempotent: a session already completed (by whichever path got '
      'there first) is left untouched, not re-persisted or re-emitted',
      () async {
        final walletRepo = _MockWalletRepository();
        final walletTxRepo = _MockWalletTransactionRepository();
        final syncController = StreamController<Wallet>.broadcast();
        addTearDown(syncController.close);
        when(
          () => walletRepo.walletSyncFinishedStream,
        ).thenAnswer((_) => syncController.stream);

        final model = _senderModel(
          originalTxId: 'sender-orig-txid',
        ).copyWith(expireAfterSec: 9999999999);
        when(
          () => local.fetchAll(onlyUnfinished: true),
        ).thenAnswer((_) async => [model]);
        when(
          () => local.fetchReceiver('bitcoin:tb1qsender?pj=https://payjo.in'),
        ).thenAnswer((_) async => null);
        // Already completed by the time the watch fires (e.g. this
        // device's own attempt succeeded in the meantime).
        final alreadyCompleted = model.copyWith(isCompleted: true);
        when(
          () => local.fetchSender('bitcoin:tb1qsender?pj=https://payjo.in'),
        ).thenAnswer((_) async => alreadyCompleted);
        when(
          () => walletTxRepo.getWalletTransaction(
            'sender-orig-txid',
            walletId: 'w1',
          ),
        ).thenAnswer(
          (_) async => _testWalletTx(txId: 'sender-orig-txid', walletId: 'w1'),
        );

        final repo = PayjoinRepositoryImpl(
          localPayjoinDatasource: local,
          pdkPayjoinDatasource: pdk,
          walletMetadataDatasource: _MockWalletMetadataDatasource(),
          seedDatasource: _MockSeedDatasource(),
          bdkWalletDatasource: _MockBdkWalletDatasource(),
          blockchainDatasource: blockchain,
          serversPort: serversPort,
          walletRepository: () => walletRepo,
          walletTransactionRepository: () => walletTxRepo,
          settingsRepository: _MockSettingsRepository(),
          labelsFacade: () => labels,
        );

        await repo.resumePayjoinsOnStartup();

        final emitted = <Payjoin>[];
        final sub = repo.payjoinStream.listen(emitted.add);

        syncController.add(_testWallet(origin: 'w1'));
        await Future<void>.delayed(Duration.zero);

        expect(emitted, isEmpty);
        verifyNever(() => local.update(any()));
        await sub.cancel();
      },
    );

    test(
      'a receiver session surviving a failed own-broadcast attempt still '
      'completes once the original transaction is later observed on-chain '
      '(the fix: _stopWatching is no longer called before attempting the '
      'broadcast, so a failed attempt no longer strands the session)',
      () async {
        final requestController =
            StreamController<PayjoinReceiverModel>.broadcast();
        addTearDown(requestController.close);
        final walletRepo = _MockWalletRepository();
        final walletTxRepo = _MockWalletTransactionRepository();
        final syncController = StreamController<Wallet>.broadcast();
        addTearDown(syncController.close);
        final settings = _MockSettingsRepository();
        when(
          () => pdk.requestsForReceivers,
        ).thenAnswer((_) => requestController.stream);
        when(
          () => settings.fetch(),
        ).thenAnswer((_) async => _testSettings(payjoinMinAmountSat: 10000));
        when(
          () => walletRepo.walletSyncFinishedStream,
        ).thenAnswer((_) => syncController.stream);

        final repo = PayjoinRepositoryImpl(
          localPayjoinDatasource: local,
          pdkPayjoinDatasource: pdk,
          walletMetadataDatasource: _MockWalletMetadataDatasource(),
          seedDatasource: _MockSeedDatasource(),
          bdkWalletDatasource: _MockBdkWalletDatasource(),
          blockchainDatasource: blockchain,
          serversPort: serversPort,
          walletRepository: () => walletRepo,
          walletTransactionRepository: () => walletTxRepo,
          settingsRepository: settings,
          labelsFacade: () => labels,
        );

        // Below minimum, so _processPayjoinRequest attempts the fallback
        // broadcast immediately — but the broadcast itself fails (e.g. no
        // network at that exact moment).
        final model = _receiverModel(originalTxId: 'orig-txid', amountSat: 500);
        when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);
        when(
          () => serversPort.runWithFallback<void>(
            network: any(named: 'network'),
            operation: any(named: 'operation'),
          ),
        ).thenThrow(Exception('no network'));
        when(
          () => walletTxRepo.getWalletTransaction('orig-txid', walletId: 'w1'),
        ).thenAnswer((_) async => null);

        final emitted = <Payjoin>[];
        final sub = repo.payjoinStream.listen(emitted.add);

        requestController.add(model);
        await Future<void>.delayed(Duration.zero);

        // Own attempt failed: _processPayjoinRequest's below-minimum branch
        // only emits on success, so just the initial "requested" event is
        // on the stream — still not completed.
        expect(emitted, hasLength(1));
        expect(emitted.single.isCompleted, isFalse);

        // The original transaction eventually lands anyway — a later
        // resume's retry, or the sender broadcasting it independently. The
        // fallback watch armed at the top of _processPayjoinRequest is what
        // catches this: it survived the failed attempt above because
        // _stopWatching is no longer called before attempting the broadcast.
        when(
          () => walletTxRepo.getWalletTransaction('orig-txid', walletId: 'w1'),
        ).thenAnswer(
          (_) async => _testWalletTx(txId: 'orig-txid', walletId: 'w1'),
        );
        syncController.add(_testWallet(origin: 'w1'));
        await Future<void>.delayed(Duration.zero);

        expect(emitted, hasLength(2));
        expect(emitted.last.status, PayjoinStatus.aborted);
        await sub.cancel();
      },
    );
  });

  group('_processPayjoinRequest below-minimum decline flow', () {
    test('declines and broadcasts the original when the amount is below the '
        'configured minimum', () async {
      final requestController =
          StreamController<PayjoinReceiverModel>.broadcast();
      final settings = _MockSettingsRepository();
      when(
        () => pdk.requestsForReceivers,
      ).thenAnswer((_) => requestController.stream);
      when(
        () => settings.fetch(),
      ).thenAnswer((_) async => _testSettings(payjoinMinAmountSat: 10000));

      final repo = PayjoinRepositoryImpl(
        localPayjoinDatasource: local,
        pdkPayjoinDatasource: pdk,
        walletMetadataDatasource: _MockWalletMetadataDatasource(),
        seedDatasource: _MockSeedDatasource(),
        bdkWalletDatasource: _MockBdkWalletDatasource(),
        blockchainDatasource: blockchain,
        serversPort: serversPort,
        walletRepository: _MockWalletRepository.new,
        walletTransactionRepository: _MockWalletTransactionRepository.new,
        settingsRepository: settings,
        labelsFacade: () => labels,
      );
      addTearDown(() => requestController.close());

      final model = _receiverModel(originalTxId: 'orig-txid', amountSat: 500);
      when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);

      final emitted = <Payjoin>[];
      final sub = repo.payjoinStream.listen(emitted.add);

      requestController.add(model);
      await Future<void>.delayed(Duration.zero);

      // Two events: the raw "requested" one, then the declined session
      //  completed via the original-transaction fallback. The full
      //  proposal-building flow (_proposePayjoin) must never run — if it
      //  did, it would throw (BdkWalletDatasource/SeedDatasource are bare
      //  mocks here) and this session would instead go through the
      //  catch-and-fallback path, producing the same completed *shape* but
      //  for the wrong reason; verify settings.fetch() was actually
      //  consulted to distinguish the two.
      expect(emitted, hasLength(2));
      expect(emitted.last.isCompleted, isTrue);
      verify(() => settings.fetch()).called(1);
      await sub.cancel();
    });
  });
}
