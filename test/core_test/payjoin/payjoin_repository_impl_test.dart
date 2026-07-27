import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart' show SignerEntity;
import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/pdk_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_input_pair_model.dart';
import 'package:bb_mobile/core/payjoin/data/repository/payjoin_repository_impl.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
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

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWalletTransactionRepository extends Mock
    implements WalletTransactionRepository {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockLabel extends Mock implements Label {}

class _FakeNewLabel extends Fake implements NewLabel {}

// ---------------------------------------------------------------------------
// Fixture helpers (adapted from the payjoin-hardening test suite to the
// work-tree PayjoinModel / Wallet / WalletTransaction constructors).
// ---------------------------------------------------------------------------

PayjoinReceiverModel _receiverModel({
  String id = 'pj1',
  String walletId = 'w1',
  String? originalTxId = 'orig-txid',
  String? proposalPsbt,
  String? txId,
  int? amountSat,
  // Defaults to already-elapsed (createdAt: 0) so isExpiryTimePassed is true
  // by default. Pass a large value to get a not-yet-expired model instead
  // (e.g. to exercise resume's live-session branches).
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

void main() {
  late _MockLocalPayjoinDatasource localDatasource;
  late _MockPdkPayjoinDatasource pdkDatasource;
  late _MockWalletMetadataDatasource walletMetadataDatasource;
  late _MockSeedDatasource seedDatasource;
  late _MockBdkWalletDatasource bdkWalletDatasource;
  late _MockBdkBitcoinBlockchainDatasource blockchainDatasource;
  late _MockElectrumServersPort serversPort;
  late _MockSettingsRepository settingsRepository;
  late _MockWalletRepository walletRepository;
  late _MockWalletTransactionRepository walletTransactionRepository;
  late _MockLabelsFacade labelsFacade;

  late StreamController<PayjoinReceiverModel> requestsController;
  late StreamController<PayjoinSenderModel> proposalsController;
  late StreamController<PayjoinModel> expiredController;

  setUpAll(() {
    registerFallbackValue(ElectrumServerNetwork.bitcoinTestnet);
    registerFallbackValue(_FakeNewLabel());
    // PayjoinModel is sealed and can't be Fake-implemented from outside its
    // library — register a real (throwaway) instance instead.
    registerFallbackValue(_receiverModel());
    // Fallback for any() matchers against BdkWalletDatasource.signPsbt's
    // `wallet` param in the real-signing-stack tests.
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
    localDatasource = _MockLocalPayjoinDatasource();
    pdkDatasource = _MockPdkPayjoinDatasource();
    walletMetadataDatasource = _MockWalletMetadataDatasource();
    seedDatasource = _MockSeedDatasource();
    bdkWalletDatasource = _MockBdkWalletDatasource();
    blockchainDatasource = _MockBdkBitcoinBlockchainDatasource();
    serversPort = _MockElectrumServersPort();
    settingsRepository = _MockSettingsRepository();
    walletRepository = _MockWalletRepository();
    walletTransactionRepository = _MockWalletTransactionRepository();
    labelsFacade = _MockLabelsFacade();

    requestsController = StreamController<PayjoinReceiverModel>.broadcast();
    proposalsController = StreamController<PayjoinSenderModel>.broadcast();
    expiredController = StreamController<PayjoinModel>.broadcast();

    when(
      () => pdkDatasource.requestsForReceivers,
    ).thenAnswer((_) => requestsController.stream);
    when(
      () => pdkDatasource.proposalsForSenders,
    ).thenAnswer((_) => proposalsController.stream);
    when(
      () => pdkDatasource.expiredPayjoins,
    ).thenAnswer((_) => expiredController.stream);
    // dispose()/stopPolling are exercised by the repository's own teardown.
    when(() => pdkDatasource.dispose()).thenAnswer((_) async {});
    when(() => pdkDatasource.stopPolling(any())).thenReturn(null);

    when(
      () => localDatasource.fetchAll(
        onlyUnfinished: any(named: 'onlyUnfinished'),
      ),
    ).thenAnswer((_) async => []);
    // The resume sweep for expired-with-failed-fallback receivers/senders —
    // empty by default, overridden in the sweep tests. Only runs from
    // resumePayjoinsOnStartup, never the constructor.
    when(() => localDatasource.fetchReceivers()).thenAnswer((_) async => []);
    when(() => localDatasource.fetchSenders()).thenAnswer((_) async => []);
    when(() => localDatasource.update(any())).thenAnswer((_) async {});

    // Passive watchers must never fire spuriously: an empty sync stream and
    // a not-found transaction lookup keep _watchForFallback/_watchForBroadcast
    // arming a harmless no-op.
    when(
      () => walletRepository.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => walletRepository.getWallet(any(), sync: any(named: 'sync')),
    ).thenAnswer((_) async => null);
    when(
      () => walletTransactionRepository.getWalletTransaction(
        any(),
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await requestsController.close();
    await proposalsController.close();
    await expiredController.close();
  });

  PayjoinRepositoryImpl buildRepository() =>
      PayjoinRepositoryImpl(
          localPayjoinDatasource: localDatasource,
          pdkPayjoinDatasource: pdkDatasource,
          walletMetadataDatasource: walletMetadataDatasource,
          seedDatasource: seedDatasource,
          bdkWalletDatasource: bdkWalletDatasource,
          blockchainDatasource: blockchainDatasource,
          serversPort: serversPort,
          walletRepository: () => walletRepository,
          walletTransactionRepository: () => walletTransactionRepository,
          settingsRepository: settingsRepository,
          labelsFacade: () => labelsFacade,
        )
        // Zero the fallback-retry delay: with the real 1s delay a permanently
        //  failing broadcast's later attempts fire (on stale mocks) during
        //  subsequent tests. No test depends on the delay's duration.
        ..fallbackRetryDelay = Duration.zero;

  PayjoinReceiverModel buildReceiverModel({
    required int amountSat,
    bool isExpired = false,
  }) =>
      PayjoinModel.receiver(
            id: 'r1',
            address: 'bcrt1qaddress',
            isTestnet: true,
            receiver: '[]',
            walletId: 'w1',
            pjUri: 'bitcoin:bcrt1qaddress?pj=https://payjo.in/x',
            maxFeeRateSatPerVb: BigInt.from(10000),
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            expireAfterSec: 86400,
            originalTxBytes: Uint8List.fromList([1, 2, 3]),
            originalTxId: 'a' * 64,
            amountSat: amountSat,
            isExpired: isExpired,
          )
          as PayjoinReceiverModel;

  group('below-minimum decline', () {
    test(
      'declines via the PDK cancel path and never proposes a payjoin — '
      'pinned so an inverted or removed threshold check cannot pass '
      'silently (the below-minimum-decline test on the branch this was '
      'adapted from could not fail before this assertion was added)',
      () async {
        when(() => settingsRepository.fetch()).thenAnswer(
          (_) async => const SettingsEntity(
            environment: Environment.testnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
            isPayjoinEnabled: true,
            payjoinMinAmountSat: 100000,
          ),
        );
        when(
          () => pdkDatasource.declineReceiverSession(any()),
        ).thenReturn('["cancelled"]');
        when(
          () => serversPort.runWithFallback<void>(
            network: any(named: 'network'),
            operation: any(named: 'operation'),
          ),
        ).thenAnswer((_) async {});
        when(() => localDatasource.fetchReceiver(any())).thenAnswer(
          (_) async => buildReceiverModel(
            amountSat: 1000,
          ).copyWith(receiver: '["cancelled"]'),
        );

        final repository = buildRepository();
        addTearDown(repository.dispose);
        // Below the 100,000 sat threshold configured above.
        requestsController.add(buildReceiverModel(amountSat: 1000));
        await pumpEventQueue();

        verify(() => pdkDatasource.declineReceiverSession(any())).called(1);
        verify(
          () => serversPort.runWithFallback<void>(
            network: any(named: 'network'),
            operation: any(named: 'operation'),
          ),
        ).called(1);
        verifyNever(
          () => pdkDatasource.proposePayjoin(
            receiverModel: any(named: 'receiverModel'),
            hasOwnedInputs: any(named: 'hasOwnedInputs'),
            hasReceiverOutput: any(named: 'hasReceiverOutput'),
            inputPairs: any(named: 'inputPairs'),
            processPsbt: any(named: 'processPsbt'),
          ),
        );
        // walletMetadataDatasource.fetch is only reached by _loadWallet,
        // which the propose path (never taken here) calls first — an
        // indirect but sufficient signal that _proposePayjoin's whole
        // chain, not just proposePayjoin itself, was skipped.
        verifyNever(() => walletMetadataDatasource.fetch(any()));
      },
    );

    test('a request at or above the minimum is not declined', () async {
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          isPayjoinEnabled: true,
          payjoinMinAmountSat: 10000,
        ),
      );
      // Let _proposePayjoin fail fast with a benign error instead of fully
      // wiring the wallet/UTXO chain — this test only cares that the
      // decline path (declineReceiverSession) is NOT taken above the
      // threshold.
      when(
        () => walletMetadataDatasource.fetch(any()),
      ).thenAnswer((_) async => null);

      final repository = buildRepository();
      addTearDown(repository.dispose);
      requestsController.add(buildReceiverModel(amountSat: 10000));
      await pumpEventQueue();

      verifyNever(() => pdkDatasource.declineReceiverSession(any()));
      // Positive signal that the PROPOSE path (not just "no decline") was
      // taken: loading the wallet is its first step.
      verify(() => walletMetadataDatasource.fetch(any())).called(1);
    });
  });

  group('resume sweep for expired receivers with a failed fallback', () {
    // The sweep now lives inside resumePayjoinsOnStartup (no longer fired
    // from the constructor), so every test here calls it explicitly.
    test('an expired-but-not-aborted receiver still holding the original tx '
        'gets a broadcast attempt at startup and is marked aborted on '
        'success — otherwise the sender payment is stranded forever '
        '(excluded from every onlyUnfinished resume)', () async {
      final stranded = buildReceiverModel(amountSat: 5000, isExpired: true);
      when(
        () => localDatasource.fetchReceivers(),
      ).thenAnswer((_) async => [stranded]);
      when(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => localDatasource.fetchReceiver(any()),
      ).thenAnswer((_) async => stranded);

      final repository = buildRepository();
      addTearDown(repository.dispose);
      await repository.resumePayjoinsOnStartup();
      await pumpEventQueue();

      verify(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).called(1);
      final updated = verify(
        () => localDatasource.update(captureAny()),
      ).captured;
      expect(
        updated.whereType<PayjoinReceiverModel>().any((m) => m.isAborted),
        isTrue,
      );
    });

    test('an already-aborted expired receiver is left alone', () async {
      final resolved = buildReceiverModel(
        amountSat: 5000,
        isExpired: true,
      ).copyWith(isAborted: true);
      when(
        () => localDatasource.fetchReceivers(),
      ).thenAnswer((_) async => [resolved]);

      final repository = buildRepository();
      addTearDown(repository.dispose);
      await repository.resumePayjoinsOnStartup();
      await pumpEventQueue();

      verifyNever(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      );
    });
  });

  group('isBelowPayjoinMinimum', () {
    test('below the threshold', () {
      expect(
        PayjoinRepositoryImpl.isBelowPayjoinMinimum(
          amountSat: 999,
          minAmountSat: 1000,
        ),
        isTrue,
      );
    });

    test('at the threshold is not below it', () {
      expect(
        PayjoinRepositoryImpl.isBelowPayjoinMinimum(
          amountSat: 1000,
          minAmountSat: 1000,
        ),
        isFalse,
      );
    });

    test('null amount is never below the threshold', () {
      expect(
        PayjoinRepositoryImpl.isBelowPayjoinMinimum(
          amountSat: null,
          minAmountSat: 1000,
        ),
        isFalse,
      );
    });
  });

  group('labelCompletedPayjoinSend', () {
    // Exercised directly rather than through the full reactive sender
    // pipeline: that needs a real, valid PSBT for BitcoinTx.fromPsbt to
    // parse (FFI-backed), which — like the existing payjoin datasource
    // tests document — isn't practical to construct offline.
    const txId =
        'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f90';

    test(
      'stores a transaction label tagged with the payjoin system label',
      () async {
        when(() => labelsFacade.store(any())).thenAnswer(
          (_) async => Ok(
            Label(
              id: 1,
              type: LabelType.transaction,
              label: LabelSystem.payjoin.label,
              reference: txId,
            ),
          ),
        );

        final repository = buildRepository();
        addTearDown(repository.dispose);
        await repository.labelCompletedPayjoinSend(txId);

        final captured =
            verify(() => labelsFacade.store(captureAny())).captured.single
                as NewLabel;
        expect(captured.type, LabelType.transaction);
        expect(captured.reference, txId);
        expect(captured.label, LabelSystem.payjoin.label);
      },
    );

    test('swallows a store failure instead of throwing', () async {
      when(
        () => labelsFacade.store(any()),
      ).thenAnswer((_) async => const Err(LabelUnexpectedFailure('boom')));

      final repository = buildRepository();
      addTearDown(repository.dispose);

      await expectLater(repository.labelCompletedPayjoinSend(txId), completes);
    });

    test('swallows a thrown exception instead of propagating it', () async {
      when(() => labelsFacade.store(any())).thenThrow(Exception('boom'));

      final repository = buildRepository();
      addTearDown(repository.dispose);

      await expectLater(repository.labelCompletedPayjoinSend(txId), completes);
    });
  });

  // -------------------------------------------------------------------------
  // Ported (and adapted) from payjoin-hardening. DESIGN DIVERGENCE: hardening
  // derived a fallback completion via `isCompleted`; the work tree has an
  // explicit `isAborted` flag, so fallback outcomes are asserted via
  // `isAborted` / `status == PayjoinStatus.aborted`. Real payjoin completion
  // stays `isCompleted` / `status == completed`.
  // -------------------------------------------------------------------------

  group('tryBroadcastOriginalTransaction manual-call idempotency guard '
      '(the public entry point only — internal fallback callers bypass it '
      'via _broadcastOriginalTransaction)', () {
    setUp(() {
      when(
        () => labelsFacade.store(any()),
      ).thenAnswer((_) async => Ok<Label, LabelFailure>(_MockLabel()));
    });

    test('refuses a receiver already completed, and returns its current '
        'state instead of re-broadcasting (+ isAborted sibling)', () async {
      final model = _receiverModel(
        originalTxId: 'orig-txid',
      ).copyWith(isCompleted: true, txId: null);
      when(
        () => localDatasource.fetchReceiver('pj1'),
      ).thenAnswer((_) async => model);

      final repository = buildRepository();
      addTearDown(repository.dispose);

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

      // isAborted sibling: a receiver already resolved via the fallback is
      // likewise refused.
      final aborted = _receiverModel(
        originalTxId: 'orig-txid',
      ).copyWith(isAborted: true, txId: null);
      when(
        () => localDatasource.fetchReceiver('pj1'),
      ).thenAnswer((_) async => aborted);

      final abortedResult = await repository.tryBroadcastOriginalTransaction(
        aborted.toEntity(),
      );

      expect(abortedResult, isNotNull);
      expect(abortedResult!.isAborted, isTrue);
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
      when(
        () => localDatasource.fetchReceiver('pj1'),
      ).thenAnswer((_) async => model);

      final repository = buildRepository();
      addTearDown(repository.dispose);
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
      when(
        () => localDatasource.fetchSender(model.uri),
      ).thenAnswer((_) async => model);

      final repository = buildRepository();
      addTearDown(repository.dispose);

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
      when(
        () => localDatasource.fetchSender(model.uri),
      ).thenAnswer((_) async => model);

      final repository = buildRepository();
      addTearDown(repository.dispose);
      await repository.tryBroadcastOriginalTransaction(model.toEntity());

      verifyNever(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      );
    });

    test(
      'allows a sender manual retry once its OWN internal fallback also '
      'gave up (isExpired, proposalPsbt still set) — no dead-end left, so '
      'this must not be permanently blocked; result is terminal (aborted)',
      () async {
        when(
          () => serversPort.runWithFallback<void>(
            network: any(named: 'network'),
            operation: any(named: 'operation'),
          ),
        ).thenAnswer((_) async {});
        final model = _senderModel(
          originalTxId: 'sender-orig-txid',
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        ).copyWith(isExpired: true);
        when(
          () => localDatasource.fetchSender(model.uri),
        ).thenAnswer((_) async => model);

        final repository = buildRepository();
        addTearDown(repository.dispose);

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
        expect(result!.isAborted, isTrue);
      },
    );

    test(
      'allows a receiver or sender manual retry while no proposal has '
      'ever been received (waiting) — result is terminal (aborted)',
      () async {
        when(
          () => serversPort.runWithFallback<void>(
            network: any(named: 'network'),
            operation: any(named: 'operation'),
          ),
        ).thenAnswer((_) async {});
        final receiverModel = _receiverModel(originalTxId: 'orig-txid');
        when(
          () => localDatasource.fetchReceiver('pj1'),
        ).thenAnswer((_) async => receiverModel);

        final repository = buildRepository();
        addTearDown(repository.dispose);

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
        expect(result!.isAborted, isTrue);
      },
    );
  });

  group('syncs the wallet after WE broadcast a transaction', () {
    // Without this, the wallet balance/tx list only picked up a broadcast
    // this repository itself just made once some unrelated sync happened to
    // run — the same staleness class of gap _watchForBroadcast's active poll
    // fixes for the receiver's own detection of the SENDER's broadcast.
    setUp(() {
      when(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => labelsFacade.store(any()),
      ).thenAnswer((_) async => Ok<Label, LabelFailure>(_MockLabel()));
    });

    test('tryBroadcastOriginalTransaction (receiver fallback) forces a '
        'synced wallet lookup after a successful broadcast', () async {
      final model = _receiverModel(walletId: 'w1', originalTxId: 'orig-txid');
      when(
        () => localDatasource.fetchReceiver('pj1'),
      ).thenAnswer((_) async => model);

      final repository = buildRepository();
      addTearDown(repository.dispose);

      await repository.tryBroadcastOriginalTransaction(model.toEntity());
      // The sync is deliberately fire-and-forget (unawaited); give its
      // Future(() => ...) wrapper a tick to run before verifying.
      await Future<void>.delayed(Duration.zero);

      verify(() => walletRepository.getWallet('w1', sync: true)).called(1);
    });

    test('tryBroadcastOriginalTransaction (sender fallback) forces a synced '
        'wallet lookup after a successful broadcast', () async {
      final model = _senderModel(
        walletId: 'w1',
        originalTxId: 'sender-orig-txid',
      );
      when(
        () => localDatasource.fetchSender(model.uri),
      ).thenAnswer((_) async => model);

      final repository = buildRepository();
      addTearDown(repository.dispose);

      await repository.tryBroadcastOriginalTransaction(model.toEntity());
      await Future<void>.delayed(Duration.zero);

      verify(() => walletRepository.getWallet('w1', sync: true)).called(1);
    });

    test('a sync failure is swallowed and does not affect the already-'
        'successful broadcast result', () async {
      when(
        () => walletRepository.getWallet(any(), sync: any(named: 'sync')),
      ).thenThrow(Exception('no network'));
      final model = _receiverModel(walletId: 'w1', originalTxId: 'orig-txid');
      when(
        () => localDatasource.fetchReceiver('pj1'),
      ).thenAnswer((_) async => model);

      final repository = buildRepository();
      addTearDown(repository.dispose);

      final result = await repository.tryBroadcastOriginalTransaction(
        model.toEntity(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(result, isNotNull);
      expect(result!.isAborted, isTrue);
    });

    // SKIP: the _broadcastPsbt real-payjoin sync test. The work tree's
    // _processPayjoinProposal re-derives the label txid via
    // BitcoinTx.fromPsbt('signed-psbt'), which throws under FFI in a unit
    // context and routes into the fallback path — the getWallet(sync: true)
    // call inside _broadcastPsbt is not cleanly isolatable from the fallback
    // path's own sync. The two fallback-side sync tests above cover the same
    // _syncWalletAfterBroadcast machinery.
  });

  group('_processExpiredPayjoin sender terminal emission (#2246)', () {
    // These drive the expiredPayjoins stream directly to exercise the
    // repository's terminal-emission semantics on the send flow.
    setUp(() {
      when(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => labelsFacade.store(any()),
      ).thenAnswer((_) async => Ok<Label, LabelFailure>(_MockLabel()));
    });

    test('emits only the aborted result (no interim expired) when the '
        'fallback broadcast succeeds', () async {
      final model = _senderModel(originalTxId: 'sender-orig-txid');
      when(
        () => localDatasource.fetchSender(model.uri),
      ).thenAnswer((_) async => model);

      final repository = buildRepository();
      addTearDown(repository.dispose);
      final emitted = <Payjoin>[];
      final sub = repository.payjoinStream.listen(emitted.add);

      expiredController.add(model.copyWith(isExpired: true));
      await Future<void>.delayed(Duration.zero);

      // Exactly one terminal event, and it is the fallback (aborted) result —
      // not the interim expired one that would race the success on the send
      // flow.
      expect(emitted, hasLength(1));
      expect(emitted.single.isAborted, isTrue);
      await sub.cancel();
    });

    test('emits the expired entity when the fallback broadcast fails so the '
        'send flow does not hang', () async {
      final model = _senderModel(originalTxId: 'sender-orig-txid');
      when(
        () => localDatasource.fetchSender(model.uri),
      ).thenAnswer((_) async => model);
      // Make the broadcast fail -> the fallback returns null.
      when(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).thenThrow(Exception('broadcast failed'));

      final repository = buildRepository();
      addTearDown(repository.dispose);
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

    test('bails out when the persisted row already completed — an expiry '
        'firing after a fallback resolution must not re-broadcast the '
        'original transaction', () async {
      // The poll's own stale copy says unfinished, but the row has since
      // been completed by _onOriginalTransactionSeen (the counterparty's
      // fallback broadcast landed on-chain).
      final staleCopy = _senderModel(originalTxId: 'sender-orig-txid');
      final completedRow = staleCopy.copyWith(isCompleted: true, txId: null);
      when(
        () => localDatasource.fetchSender(staleCopy.uri),
      ).thenAnswer((_) async => completedRow);

      final repository = buildRepository();
      addTearDown(repository.dispose);
      final emitted = <Payjoin>[];
      final sub = repository.payjoinStream.listen(emitted.add);

      expiredController.add(staleCopy.copyWith(isExpired: true));
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      );
      verifyNever(() => localDatasource.update(any()));
      expect(emitted, isEmpty);
      await sub.cancel();
    });

    test('bails out when the persisted row is already aborted — the '
        'isAborted sibling of the completed-bail guard', () async {
      final staleCopy = _senderModel(originalTxId: 'sender-orig-txid');
      final abortedRow = staleCopy.copyWith(isAborted: true, txId: null);
      when(
        () => localDatasource.fetchSender(staleCopy.uri),
      ).thenAnswer((_) async => abortedRow);

      final repository = buildRepository();
      addTearDown(repository.dispose);
      final emitted = <Payjoin>[];
      final sub = repository.payjoinStream.listen(emitted.add);

      expiredController.add(staleCopy.copyWith(isExpired: true));
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      );
      verifyNever(() => localDatasource.update(any()));
      expect(emitted, isEmpty);
      await sub.cancel();
    });

    test('bails out when the session row no longer exists', () async {
      final staleCopy = _senderModel(originalTxId: 'sender-orig-txid');
      when(
        () => localDatasource.fetchSender(staleCopy.uri),
      ).thenAnswer((_) async => null);

      final repository = buildRepository();
      addTearDown(repository.dispose);
      final emitted = <Payjoin>[];
      final sub = repository.payjoinStream.listen(emitted.add);

      expiredController.add(staleCopy.copyWith(isExpired: true));
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      );
      expect(emitted, isEmpty);
      await sub.cancel();
    });

    test(
      'decides on the persisted row, not the stale event copy: a '
      'proposal persisted since the copy was captured suppresses the '
      'original-transaction fallback and keeps the proposal intact',
      () async {
        final staleCopy = _senderModel(originalTxId: 'sender-orig-txid');
        final freshRow = staleCopy.copyWith(
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        );
        when(
          () => localDatasource.fetchSender(staleCopy.uri),
        ).thenAnswer((_) async => freshRow);

        final repository = buildRepository();
        addTearDown(repository.dispose);
        final emitted = <Payjoin>[];
        final sub = repository.payjoinStream.listen(emitted.add);

        expiredController.add(staleCopy.copyWith(isExpired: true));
        await Future<void>.delayed(Duration.zero);

        // Once a proposal is out the sender owns broadcasting the payjoin
        // transaction — no original fallback.
        verifyNever(
          () => serversPort.runWithFallback<void>(
            network: any(named: 'network'),
            operation: any(named: 'operation'),
          ),
        );
        // The expired marker is persisted on the FRESH row: persisting the
        // stale copy would clobber the proposal (insertOnConflictUpdate
        // replaces the whole row).
        final persisted =
            verify(() => localDatasource.update(captureAny())).captured.single
                as PayjoinSenderModel;
        expect(persisted.proposalPsbt, 'cHNidP9wcm9wb3NhbA==');
        expect(persisted.isExpired, isTrue);
        expect(emitted.single.isExpired, isTrue);
        await sub.cancel();
      },
    );
  });

  group('_processPayjoinProposal terminal emission on broadcast failure '
      '(#2246)', () {
    // A received proposal whose signing/broadcast fails must still produce a
    // terminal event, because by the time a proposal arrives the poll timer
    // that would otherwise raise an expiry is already cancelled — nothing
    // else will ever emit for this session again.
    setUp(() {
      // _loadWallet throws when metadata is missing — the simplest way to
      // drive _processPayjoinProposal's catch without mocking a full signing
      // stack.
      when(
        () => walletMetadataDatasource.fetch(any()),
      ).thenAnswer((_) async => null);
      when(
        () => labelsFacade.store(any()),
      ).thenAnswer((_) async => Ok<Label, LabelFailure>(_MockLabel()));
    });

    test('falls back to broadcasting the original psbt and completes '
        '(aborted) when signing/broadcasting the proposal fails', () async {
      when(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).thenAnswer((_) async {});
      final model = _senderModel(
        originalTxId: 'sender-orig-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      when(
        () => localDatasource.fetchSender(model.uri),
      ).thenAnswer((_) async => model);

      final repository = buildRepository();
      addTearDown(repository.dispose);
      final emitted = <Payjoin>[];
      final sub = repository.payjoinStream.listen(emitted.add);

      proposalsController.add(model);
      await Future<void>.delayed(Duration.zero);

      // Two events: the raw "proposal received" one, then the fallback's
      // terminal aborted one (the original transaction still got broadcast,
      // so the send flow can resolve to success).
      expect(emitted, hasLength(2));
      expect(emitted.last.isAborted, isTrue);
      await sub.cancel();
    });

    test(
      'marks the session terminally failed (expired) when both the '
      'proposal and the original-transaction fallback fail to broadcast',
      () async {
        final model = _senderModel(
          originalTxId: 'sender-orig-txid',
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        );
        when(
          () => localDatasource.fetchSender(model.uri),
        ).thenAnswer((_) async => model);
        when(
          () => serversPort.runWithFallback<void>(
            network: any(named: 'network'),
            operation: any(named: 'operation'),
          ),
        ).thenThrow(Exception('broadcast failed'));

        final repository = buildRepository();
        addTearDown(repository.dispose);
        final emitted = <Payjoin>[];
        final sub = repository.payjoinStream.listen(emitted.add);

        proposalsController.add(model);
        await Future<void>.delayed(Duration.zero);

        // Terminal failure, not silence: the send flow must never hang forever
        // waiting for an event that will never arrive.
        expect(emitted, hasLength(2));
        expect(emitted.last.isExpired, isTrue);
        await sub.cancel();
      },
    );

    test('bails out when the persisted session already aborted — a proposal '
        'event arriving after the counterparty fell back must not resurrect '
        'the row nor sign/broadcast', () async {
      // The proposal event carries the datasource's stale in-memory copy, but
      // the persisted row was aborted since (the fallback watcher saw the
      // original transaction land on-chain).
      final staleCopy = _senderModel(
        originalTxId: 'sender-orig-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      final abortedRow = staleCopy.copyWith(isAborted: true, txId: null);
      when(
        () => localDatasource.fetchSender(staleCopy.uri),
      ).thenAnswer((_) async => abortedRow);

      final repository = buildRepository();
      addTearDown(repository.dispose);
      final emitted = <Payjoin>[];
      final sub = repository.payjoinStream.listen(emitted.add);

      proposalsController.add(staleCopy);
      await Future<void>.delayed(Duration.zero);

      // No sign/broadcast, no persist, no emission: the session already
      // resolved another way.
      verifyNever(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      );
      verifyNever(() => localDatasource.update(any()));
      expect(emitted, isEmpty);
      await sub.cancel();
    });

    test('a DB throw in the proposal handler is caught and logged, never '
        'escaping the stream listener as an unhandled zone error', () async {
      // The re-fetch guard sits OUTSIDE the handler's inner try/catch: a
      // throw here used to escape .listen() straight into the zone.
      final model = _senderModel(
        originalTxId: 'sender-orig-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      when(
        () => localDatasource.fetchSender(model.uri),
      ).thenThrow(Exception('db unavailable'));

      final repository = buildRepository();
      addTearDown(repository.dispose);

      proposalsController.add(model);
      await Future<void>.delayed(Duration.zero);

      // Surviving to here IS the assertion (an escaped async error fails the
      // test); the repository must also still process later events.
      when(
        () => localDatasource.fetchSender(model.uri),
      ).thenAnswer((_) async => model.copyWith(isAborted: true));
      proposalsController.add(model);
      await Future<void>.delayed(Duration.zero);
    });

    test('a DB throw in the expiry handler is caught and logged, never '
        'escaping the stream listener as an unhandled zone error', () async {
      final model = _senderModel(
        originalTxId: 'sender-orig-txid',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      );
      when(
        () => localDatasource.fetchSender(model.uri),
      ).thenThrow(Exception('db unavailable'));

      final repository = buildRepository();
      addTearDown(repository.dispose);

      expiredController.add(model.copyWith(isExpired: true));
      await Future<void>.delayed(Duration.zero);
    });
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
          () => localDatasource.fetchAll(onlyUnfinished: true),
        ).thenAnswer((_) async => [bad, ok]);
        // _processExpiredPayjoin re-fetches the persisted row before acting
        //  (stale-copy guard) — serve each session's own row back.
        when(
          () => localDatasource.fetchReceiver('bad'),
        ).thenAnswer((_) async => bad);
        when(
          () => localDatasource.fetchReceiver('ok'),
        ).thenAnswer((_) async => ok);
        // "bad"'s persist throws (e.g. a transient DB failure); "ok"'s must
        //  still go through despite "bad" throwing first in the loop.
        when(
          () => localDatasource.update(
            any(that: predicate<PayjoinModel>((m) => m.id == 'bad')),
          ),
        ).thenThrow(Exception('boom'));
        when(
          () => localDatasource.update(
            any(that: predicate<PayjoinModel>((m) => m.id == 'ok')),
          ),
        ).thenAnswer((_) async {});

        final repository = buildRepository();
        addTearDown(repository.dispose);
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

  group('_watchForBroadcast active polling', () {
    // The passive watcher only reacts to walletSyncFinishedStream, i.e. to
    // syncs triggered by something else entirely. The active poll forces
    // bounded sync'd lookups itself.
    late StreamController<Wallet> syncController;

    setUp(() {
      syncController = StreamController<Wallet>.broadcast();
      when(
        () => walletRepository.walletSyncFinishedStream,
      ).thenAnswer((_) => syncController.stream);
      when(
        () => labelsFacade.store(any()),
      ).thenAnswer((_) async => Ok<Label, LabelFailure>(_MockLabel()));

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
        () => localDatasource.fetchAll(onlyUnfinished: true),
      ).thenAnswer((_) async => [model]);
      when(
        () => localDatasource.fetchReceiver('pj1'),
      ).thenAnswer((_) async => model);
    });

    tearDown(() => syncController.close());

    test('completes the session via a forced-sync lookup when no wallet sync '
        'ever happens, then stops polling', () {
      fakeAsync((async) {
        var txSeen = false;
        when(
          () => walletTransactionRepository.getWalletTransaction(
            'payjoin-txid',
            walletId: 'w1',
            sync: true,
          ),
        ).thenAnswer(
          (_) async => txSeen
              ? _testWalletTx(txId: 'payjoin-txid', walletId: 'w1')
              : null,
        );

        final repo = buildRepository();
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
          () => walletTransactionRepository.getWalletTransaction(
            'payjoin-txid',
            walletId: 'w1',
            sync: true,
          ),
        ).called(2);

        // Completion is one-shot: no further forced syncs afterwards.
        async.elapse(const Duration(hours: 2));
        verifyNever(
          () => walletTransactionRepository.getWalletTransaction(
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
          () => walletTransactionRepository.getWalletTransaction(
            'payjoin-txid',
            walletId: 'w1',
            sync: true,
          ),
        ).thenAnswer((_) async => null);
        // Passive (local, non-forced) lookups see it once txSeen flips.
        when(
          () => walletTransactionRepository.getWalletTransaction(
            'payjoin-txid',
            walletId: 'w1',
          ),
        ).thenAnswer(
          (_) async => txSeen
              ? _testWalletTx(txId: 'payjoin-txid', walletId: 'w1')
              : null,
        );

        final repo = buildRepository();
        unawaited(repo.resumePayjoinsOnStartup());
        async.flushMicrotasks();

        final emitted = <Payjoin>[];
        repo.payjoinStream.listen(emitted.add);

        // Way past the whole active-poll schedule: exactly maxAttempts
        // forced syncs ran, then the poll chain stopped rescheduling.
        async.elapse(const Duration(hours: 3));
        verify(
          () => walletTransactionRepository.getWalletTransaction(
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

  group('post-broadcast visibility watch (own fallback broadcast)', () {
    // After WE broadcast the original transaction, the single unawaited
    // wallet sync can be throttled or race the broadcast. The original-tx
    // watch re-armed by _broadcastOriginalTransaction must keep forcing
    // DIRECT sync'd lookups until the tx is visible, then tear itself down
    // without emitting duplicate events.
    late StreamController<Wallet> syncController;

    setUp(() {
      syncController = StreamController<Wallet>.broadcast();
      when(
        () => walletRepository.walletSyncFinishedStream,
      ).thenAnswer((_) => syncController.stream);
      when(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => labelsFacade.store(any()),
      ).thenAnswer((_) async => Ok<Label, LabelFailure>(_MockLabel()));
    });

    tearDown(() => syncController.close());

    test('keeps forcing sync\'d lookups until the broadcast original is '
        'visible in the wallet, then tears down', () {
      fakeAsync((async) {
        var txSeen = false;
        when(
          () => walletTransactionRepository.getWalletTransaction(
            'orig-txid',
            walletId: 'w1',
            sync: true,
          ),
        ).thenAnswer(
          (_) async =>
              txSeen ? _testWalletTx(txId: 'orig-txid', walletId: 'w1') : null,
        );

        // The row is re-fetched several times along the way (the manual
        // guard, the broadcast itself, and the visibility watch's completion
        // handler) — serve back whatever was last persisted so the watch
        // sees the completed row once the broadcast stored it.
        var row = _receiverModel(
          id: 'pj1',
          walletId: 'w1',
          originalTxId: 'orig-txid',
          expireAfterSec: 9999999999,
        );
        when(
          () => localDatasource.fetchReceiver('pj1'),
        ).thenAnswer((_) async => row);
        when(() => localDatasource.update(any())).thenAnswer((
          invocation,
        ) async {
          row = invocation.positionalArguments.single as PayjoinReceiverModel;
        });

        final repo = buildRepository();

        final emitted = <Payjoin>[];
        repo.payjoinStream.listen(emitted.add);

        unawaited(repo.tryBroadcastOriginalTransaction(row.toEntity()));
        async.flushMicrotasks();

        // First poll: the wallet doesn't see the tx yet (throttled sync /
        // raced broadcast).
        async.elapse(PayjoinRepositoryImpl.broadcastPollInitialDelay);

        // The next backed-off poll finds it — no walletSyncFinishedStream
        // event ever fired in this test, so only the forced lookups can
        // have made it visible.
        txSeen = true;
        async.elapse(PayjoinRepositoryImpl.broadcastPollInitialDelay * 2);
        async.flushMicrotasks();

        verify(
          () => walletTransactionRepository.getWalletTransaction(
            'orig-txid',
            walletId: 'w1',
            sync: true,
          ),
        ).called(2);

        // The public manual-broadcast entry point emits the aborted result
        // exactly once (so other open watchers of this session learn of it);
        // the re-armed visibility watch then resolves as a PURE TEARDOWN —
        // no SECOND terminal event — because the session is already aborted.
        expect(emitted, hasLength(1));
        expect(emitted.single.isAborted, isTrue);
        async.elapse(const Duration(hours: 2));
        verifyNever(
          () => walletTransactionRepository.getWalletTransaction(
            'orig-txid',
            walletId: 'w1',
            sync: true,
          ),
        );
      });
    });
  });

  group('_watchForFallback (the counterparty fell back independently)', () {
    // Both sides hold their own copy of the original transaction and can
    // each independently decide to broadcast it. Before this watch existed,
    // only the side that actually broadcast it persisted the terminal state
    // — the OTHER side had no way to find out and just kept waiting on its
    // own session.
    setUp(() {
      when(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => labelsFacade.store(any()),
      ).thenAnswer((_) async => Ok<Label, LabelFailure>(_MockLabel()));
    });

    test('a sender still waiting for a proposal is resolved (aborted) once '
        'the original transaction appears in its wallet — the receiver '
        'broadcast it independently and the sender would otherwise have '
        'waited out its own full expiry with no signal', () async {
      final syncController = StreamController<Wallet>.broadcast();
      addTearDown(syncController.close);
      when(
        () => walletRepository.walletSyncFinishedStream,
      ).thenAnswer((_) => syncController.stream);

      // Not yet expired, no proposal received yet: _resumeOne's sender branch
      // arms _watchForFallback unconditionally.
      final model = _senderModel(
        originalTxId: 'sender-orig-txid',
      ).copyWith(expireAfterSec: 9999999999);
      when(
        () => localDatasource.fetchAll(onlyUnfinished: true),
      ).thenAnswer((_) async => [model]);
      // _onOriginalTransactionSeen always tries the receiver table first.
      when(
        () => localDatasource.fetchReceiver(
          'bitcoin:tb1qsender?pj=https://payjo.in',
        ),
      ).thenAnswer((_) async => null);
      when(
        () => localDatasource.fetchSender(
          'bitcoin:tb1qsender?pj=https://payjo.in',
        ),
      ).thenAnswer((_) async => model);

      // The original transaction is now visible in the sender's own wallet —
      // broadcast by the receiver, not by this device.
      when(
        () => walletTransactionRepository.getWalletTransaction(
          'sender-orig-txid',
          walletId: 'w1',
        ),
      ).thenAnswer(
        (_) async => _testWalletTx(txId: 'sender-orig-txid', walletId: 'w1'),
      );

      final repo = buildRepository();
      addTearDown(repo.dispose);

      await repo.resumePayjoinsOnStartup();

      final emitted = <Payjoin>[];
      final sub = repo.payjoinStream.listen(emitted.add);

      syncController.add(_testWallet(origin: 'w1'));
      await Future<void>.delayed(Duration.zero);

      expect(emitted, hasLength(1));
      expect(emitted.single.status, PayjoinStatus.aborted);
      expect(emitted.single.isAborted, isTrue);
      expect((emitted.single as PayjoinSender).txId, isNull);
      await sub.cancel();
    });

    test('idempotent: a session already terminal (isAborted set by whichever '
        'path got there first) is left untouched, not re-persisted or '
        're-emitted', () async {
      final syncController = StreamController<Wallet>.broadcast();
      addTearDown(syncController.close);
      when(
        () => walletRepository.walletSyncFinishedStream,
      ).thenAnswer((_) => syncController.stream);

      final model = _senderModel(
        originalTxId: 'sender-orig-txid',
      ).copyWith(expireAfterSec: 9999999999);
      when(
        () => localDatasource.fetchAll(onlyUnfinished: true),
      ).thenAnswer((_) async => [model]);
      when(
        () => localDatasource.fetchReceiver(
          'bitcoin:tb1qsender?pj=https://payjo.in',
        ),
      ).thenAnswer((_) async => null);
      // Already resolved (aborted) by the time the watch fires.
      final alreadyAborted = model.copyWith(isAborted: true, txId: null);
      when(
        () => localDatasource.fetchSender(
          'bitcoin:tb1qsender?pj=https://payjo.in',
        ),
      ).thenAnswer((_) async => alreadyAborted);
      when(
        () => walletTransactionRepository.getWalletTransaction(
          'sender-orig-txid',
          walletId: 'w1',
        ),
      ).thenAnswer(
        (_) async => _testWalletTx(txId: 'sender-orig-txid', walletId: 'w1'),
      );

      final repo = buildRepository();
      addTearDown(repo.dispose);

      await repo.resumePayjoinsOnStartup();

      final emitted = <Payjoin>[];
      final sub = repo.payjoinStream.listen(emitted.add);

      syncController.add(_testWallet(origin: 'w1'));
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isEmpty);
      verifyNever(() => localDatasource.update(any()));
      await sub.cancel();
    });

    test('a receiver session surviving a failed own-broadcast attempt still '
        'resolves (aborted) once the original transaction is later observed '
        'on-chain (the fix: _stopWatching is no longer called before '
        'attempting the broadcast, so a failed attempt no longer strands the '
        'session)', () async {
      final syncController = StreamController<Wallet>.broadcast();
      addTearDown(syncController.close);
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _testSettings(payjoinMinAmountSat: 10000));
      when(
        () => walletRepository.walletSyncFinishedStream,
      ).thenAnswer((_) => syncController.stream);

      final repo = buildRepository();
      addTearDown(repo.dispose);

      // Below minimum, so _processPayjoinRequest attempts the fallback
      // broadcast immediately — but the broadcast itself fails.
      final model = _receiverModel(originalTxId: 'orig-txid', amountSat: 500);
      when(
        () => localDatasource.fetchReceiver('pj1'),
      ).thenAnswer((_) async => model);
      when(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).thenThrow(Exception('no network'));
      when(
        () => walletTransactionRepository.getWalletTransaction(
          'orig-txid',
          walletId: 'w1',
        ),
      ).thenAnswer((_) async => null);

      final emitted = <Payjoin>[];
      final sub = repo.payjoinStream.listen(emitted.add);

      requestsController.add(model);
      await Future<void>.delayed(Duration.zero);

      // Own attempt failed: _processPayjoinRequest's below-minimum branch
      // only emits on success, so just the initial "requested" event is on
      // the stream — still not resolved.
      expect(emitted, hasLength(1));
      expect(emitted.single.isAborted, isFalse);

      // The original transaction eventually lands anyway. The fallback
      // watch armed at the top of _processPayjoinRequest catches this: it
      // survived the failed attempt because _stopWatching is no longer
      // called before attempting the broadcast.
      when(
        () => walletTransactionRepository.getWalletTransaction(
          'orig-txid',
          walletId: 'w1',
        ),
      ).thenAnswer(
        (_) async => _testWalletTx(txId: 'orig-txid', walletId: 'w1'),
      );
      syncController.add(_testWallet(origin: 'w1'));
      await Future<void>.delayed(Duration.zero);

      expect(emitted, hasLength(2));
      expect(emitted.last.status, PayjoinStatus.aborted);
      await sub.cancel();
    });
  });

  group('confirmed-first input preference in the propose path', () {
    // _filterAvailableUtxos must hand PDK's tryPreservingPrivacy only
    // confirmed candidates when any exist: PDK selects on privacy heuristics
    // alone, and a payjoin spending our unconfirmed input can be invalidated
    // by an RBF of that input's parent after both sides consider the payment
    // done. Unconfirmed-only wallets still contribute (payjoin eligibility
    // deliberately counts unconfirmed balance), so the preference must fall
    // back rather than filter to nothing — and it must not fire at all when
    // the confirmed candidates are too small for the payment.
    BitcoinWalletUtxoModel utxo({
      required String txId,
      required int confirmations,
      int amountSat = 100000,
    }) =>
        WalletUtxoModel.bitcoin(
              txId: txId,
              vout: 0,
              amountSat: BigInt.from(amountSat),
              scriptPubkey: Uint8List.fromList([0]),
              address: 'tb1qtest',
              isExternalKeyChain: false,
              confirmations: confirmations,
            )
            as BitcoinWalletUtxoModel;

    // Arranges the full propose path (same scaffolding as the watcher-arming
    // group's request test) and returns the inputPairs the repository handed
    // to proposePayjoin for the given wallet utxo set.
    List<PayjoinInputPairModel> proposedPairsFor(
      FakeAsync async,
      List<WalletUtxoModel> utxos,
    ) {
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _testSettings(payjoinMinAmountSat: 10000));
      final origin = WalletMetadataService.encodeOrigin(
        fingerprint: '00000000',
        network: Network.bitcoinTestnet,
        scriptType: ScriptType.bip84,
      );
      when(() => walletMetadataDatasource.fetch('w1')).thenAnswer(
        (_) async => WalletMetadataModel(
          id: origin,
          masterFingerprint: '00000000',
          xpubFingerprint: '00000000',
          isEncryptedVaultTested: false,
          isPhysicalBackupTested: false,
          xpub: '',
          externalPublicDescriptor: '',
          internalPublicDescriptor: '',
          signer: Signer.local,
          isDefault: false,
        ),
      );
      when(() => seedDatasource.get('00000000')).thenAnswer(
        (_) async =>
            const SeedModel.mnemonic(mnemonicWords: ['abandon'])
                as MnemonicSeedModel,
      );
      when(
        () => bdkWalletDatasource.getUtxos(wallet: any(named: 'wallet')),
      ).thenAnswer((_) async => utxos);
      when(
        () => bdkWalletDatasource.createIsMineChecker(
          wallet: any(named: 'wallet'),
        ),
      ).thenAnswer(
        (_) async =>
            (Uint8List _) => true,
      );
      when(
        () =>
            bdkWalletDatasource.createPsbtSigner(wallet: any(named: 'wallet')),
      ).thenAnswer(
        (_) async =>
            (String psbt) => psbt,
      );
      final requestModel = _receiverModel(
        id: 'pj1',
        walletId: 'w1',
        amountSat: 10000,
        expireAfterSec: 9999999999,
      );
      when(
        () => localDatasource.fetchReceiver('pj1'),
      ).thenAnswer((_) async => requestModel);
      // No txId on the returned model: the broadcast watcher never arms, so
      // the propose call is the last interaction this test cares about.
      when(
        () => pdkDatasource.proposePayjoin(
          receiverModel: any(named: 'receiverModel'),
          hasOwnedInputs: any(named: 'hasOwnedInputs'),
          hasReceiverOutput: any(named: 'hasReceiverOutput'),
          inputPairs: any(named: 'inputPairs'),
          processPsbt: any(named: 'processPsbt'),
        ),
      ).thenAnswer(
        (_) async =>
            requestModel.copyWith(proposalPsbt: 'cHNidP9wcm9wb3NhbA=='),
      );

      buildRepository();
      requestsController.add(requestModel);
      async.flushMicrotasks();

      return verify(
            () => pdkDatasource.proposePayjoin(
              receiverModel: any(named: 'receiverModel'),
              hasOwnedInputs: any(named: 'hasOwnedInputs'),
              hasReceiverOutput: any(named: 'hasReceiverOutput'),
              inputPairs: captureAny(named: 'inputPairs'),
              processPsbt: any(named: 'processPsbt'),
            ),
          ).captured.single
          as List<PayjoinInputPairModel>;
    }

    test('only confirmed utxos are offered when one covers the payment', () {
      fakeAsync((async) {
        final pairs = proposedPairsFor(async, [
          utxo(txId: 'unconfirmed-utxo', confirmations: 0),
          utxo(txId: 'confirmed-utxo', confirmations: 2),
        ]);

        expect(pairs.map((p) => p.txId), ['confirmed-utxo']);
      });
    });

    test('a confirmed utxo too small for the payment does not shut out a '
        'well-sized unconfirmed one — forcing dust on avoid_uih would trade '
        "the proposal's privacy gain for the RBF mitigation", () {
      fakeAsync((async) {
        // Payment is 10 000 sat (see proposedPairsFor's receiver model).
        final pairs = proposedPairsFor(async, [
          utxo(txId: 'confirmed-dust', confirmations: 2, amountSat: 1000),
          utxo(txId: 'unconfirmed-usable', confirmations: 0),
        ]);

        expect(
          pairs.map((p) => p.txId),
          containsAll(['confirmed-dust', 'unconfirmed-usable']),
        );
      });
    });

    test('unconfirmed utxos are still offered when nothing is confirmed — '
        'fresh wallets must activate payjoin immediately', () {
      fakeAsync((async) {
        final pairs = proposedPairsFor(async, [
          utxo(txId: 'unconfirmed-a', confirmations: 0),
          utxo(txId: 'unconfirmed-b', confirmations: 0),
        ]);

        expect(
          pairs.map((p) => p.txId),
          containsAll(['unconfirmed-a', 'unconfirmed-b']),
        );
      });
    });
  });

  group('watcher arming (broadcast + fallback) on the request / resume / '
      'expired-else paths', () {
    // These pin that the reactive handlers ARM the broadcast/fallback
    // watchers on the paths that must keep a live session detectable. Each
    // proves the watch is live by making its target txid visible through a
    // FORCED (sync: true) lookup and elapsing the active poll under
    // fakeAsync — the same technique the sibling '_watchForBroadcast active
    // polling' / '_watchForFallback' groups use — then asserting the
    // terminal stream emission the watcher's onSeen handler produces.
    setUp(() {
      when(
        () => serversPort.runWithFallback<void>(
          network: any(named: 'network'),
          operation: any(named: 'operation'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => labelsFacade.store(any()),
      ).thenAnswer((_) async => Ok<Label, LabelFailure>(_MockLabel()));
    });

    test('_processPayjoinRequest arms _watchForBroadcast after a successful '
        'propose — the receiver session completes once the sender broadcasts '
        'the payjoin transaction', () {
      fakeAsync((async) {
        // A request AT the minimum, so _processPayjoinRequest takes the
        // propose path (not the below-minimum decline).
        when(
          () => settingsRepository.fetch(),
        ).thenAnswer((_) async => _testSettings(payjoinMinAmountSat: 10000));

        // _loadWallet's dependencies: a decodable-origin metadata row and a
        // mnemonic seed. The mnemonic is only join()'d into a WalletModel
        // that getUtxos (mocked) receives — never expanded to a seed here,
        // so any placeholder words are fine.
        final origin = WalletMetadataService.encodeOrigin(
          fingerprint: '00000000',
          network: Network.bitcoinTestnet,
          scriptType: ScriptType.bip84,
        );
        when(() => walletMetadataDatasource.fetch('w1')).thenAnswer(
          (_) async => WalletMetadataModel(
            id: origin,
            masterFingerprint: '00000000',
            xpubFingerprint: '00000000',
            isEncryptedVaultTested: false,
            isPhysicalBackupTested: false,
            xpub: '',
            externalPublicDescriptor: '',
            internalPublicDescriptor: '',
            signer: Signer.local,
            isDefault: false,
          ),
        );
        when(() => seedDatasource.get('00000000')).thenAnswer(
          (_) async =>
              const SeedModel.mnemonic(mnemonicWords: ['abandon'])
                  as MnemonicSeedModel,
        );

        // One owned bitcoin utxo so _filterAvailableUtxos yields a non-empty
        // input set and _proposePayjoin doesn't bail with NoInputs.
        when(
          () => bdkWalletDatasource.getUtxos(wallet: any(named: 'wallet')),
        ).thenAnswer(
          (_) async => [
            WalletUtxoModel.bitcoin(
                  txId: 'utxo-txid',
                  vout: 0,
                  amountSat: BigInt.from(100000),
                  scriptPubkey: Uint8List.fromList([0]),
                  address: 'tb1qtest',
                  isExternalKeyChain: false,
                )
                as BitcoinWalletUtxoModel,
          ],
        );
        when(
          () => bdkWalletDatasource.createIsMineChecker(
            wallet: any(named: 'wallet'),
          ),
        ).thenAnswer(
          (_) async =>
              (Uint8List _) => true,
        );
        when(
          () => bdkWalletDatasource.createPsbtSigner(
            wallet: any(named: 'wallet'),
          ),
        ).thenAnswer(
          (_) async =>
              (String psbt) => psbt,
        );

        final requestModel = _receiverModel(
          id: 'pj1',
          walletId: 'w1',
          originalTxId: 'orig-txid',
          amountSat: 10000,
          expireAfterSec: 9999999999,
        );
        // getUtxosFrozenByOngoingPayjoins reads fetchAll(onlyUnfinished) —
        // kept empty (setUp default) so it never touches FFI BitcoinTx.
        // _proposePayjoin re-fetches the receiver row before proposing.
        when(
          () => localDatasource.fetchReceiver('pj1'),
        ).thenAnswer((_) async => requestModel);
        // proposePayjoin (FFI-backed in production) is mocked to return a
        // proposal-sent model carrying BOTH proposalPsbt and txId — the two
        // fields _processPayjoinRequest gates the _watchForBroadcast arming
        // on.
        when(
          () => pdkDatasource.proposePayjoin(
            receiverModel: any(named: 'receiverModel'),
            hasOwnedInputs: any(named: 'hasOwnedInputs'),
            hasReceiverOutput: any(named: 'hasReceiverOutput'),
            inputPairs: any(named: 'inputPairs'),
            processPsbt: any(named: 'processPsbt'),
          ),
        ).thenAnswer(
          (_) async => requestModel.copyWith(
            proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
            txId: 'payjoin-txid',
          ),
        );

        var txSeen = false;
        when(
          () => walletTransactionRepository.getWalletTransaction(
            'payjoin-txid',
            walletId: 'w1',
            sync: true,
          ),
        ).thenAnswer(
          (_) async => txSeen
              ? _testWalletTx(txId: 'payjoin-txid', walletId: 'w1')
              : null,
        );
        // The completion handler re-fetches the receiver row.
        when(() => localDatasource.fetchReceiver('pj1')).thenAnswer(
          (_) async => requestModel.copyWith(
            proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
            txId: 'payjoin-txid',
          ),
        );

        final repo = buildRepository();
        final emitted = <Payjoin>[];
        repo.payjoinStream.listen(emitted.add);

        requestsController.add(requestModel);
        async.flushMicrotasks();

        // The proposal-sent event is on the stream; the broadcast watcher is
        // now armed. The sender broadcasts; the forced poll finds the tx and
        // completes the session — no wallet-sync event ever fired.
        txSeen = true;
        async.elapse(PayjoinRepositoryImpl.broadcastPollInitialDelay);
        async.flushMicrotasks();

        expect(
          emitted.any((p) => p.isCompleted),
          isTrue,
          reason:
              'the armed _watchForBroadcast should complete the session '
              'once the payjoin txid becomes visible via a forced sync',
        );
      });
    });

    test('_resumeOne arms BOTH watchers for a receiver with a proposal '
        'already sent — the broadcast watcher completes the session once the '
        'payjoin transaction becomes visible', () {
      fakeAsync((async) {
        // Not expiry-passed, proposal already sent, txId + originalTxId set:
        // _resumeOne's `model.txId != null` branch arms _watchForBroadcast
        // (payjoin-txid) AND _watchForFallback (originalTxId).
        final model = _receiverModel(
          id: 'pj1',
          walletId: 'w1',
          originalTxId: 'orig-txid',
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
          txId: 'payjoin-txid',
          expireAfterSec: 9999999999,
        );
        when(
          () => localDatasource.fetchAll(onlyUnfinished: true),
        ).thenAnswer((_) async => [model]);
        when(
          () => localDatasource.fetchReceiver('pj1'),
        ).thenAnswer((_) async => model);

        var txSeen = false;
        when(
          () => walletTransactionRepository.getWalletTransaction(
            'payjoin-txid',
            walletId: 'w1',
            sync: true,
          ),
        ).thenAnswer(
          (_) async => txSeen
              ? _testWalletTx(txId: 'payjoin-txid', walletId: 'w1')
              : null,
        );

        final repo = buildRepository();
        unawaited(repo.resumePayjoinsOnStartup());
        async.flushMicrotasks();

        final emitted = <Payjoin>[];
        repo.payjoinStream.listen(emitted.add);

        // The broadcast watcher (armed by resume) fires the moment the
        // payjoin tx becomes visible via a forced poll.
        txSeen = true;
        async.elapse(PayjoinRepositoryImpl.broadcastPollInitialDelay);
        async.flushMicrotasks();

        expect(emitted, hasLength(1));
        expect(emitted.single.isCompleted, isTrue);
      });
    });

    test('the expired-else branch re-arms _watchForBroadcast for a resumed, '
        'expiry-passed receiver whose proposal was already sent — the '
        'session still completes when the payjoin transaction lands, despite '
        'having been marked expired', () {
      fakeAsync((async) {
        // Expiry-passed (createdAt: 0, small expireAfterSec) with a proposal
        // already out and a payjoin txId: _resumeOne routes it through
        // _processExpiredPayjoin, whose else branch persists the expired
        // marker AND re-arms _watchForBroadcast(txId).
        final model = _receiverModel(
          id: 'pj1',
          walletId: 'w1',
          originalTxId: 'orig-txid',
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
          txId: 'payjoin-txid',
          expireAfterSec: 1,
        );
        when(
          () => localDatasource.fetchAll(onlyUnfinished: true),
        ).thenAnswer((_) async => [model]);
        // _processExpiredPayjoin re-fetches the persisted row (stale-copy
        // guard); the completion handler re-fetches it too.
        when(
          () => localDatasource.fetchReceiver('pj1'),
        ).thenAnswer((_) async => model);

        var txSeen = false;
        when(
          () => walletTransactionRepository.getWalletTransaction(
            'payjoin-txid',
            walletId: 'w1',
            sync: true,
          ),
        ).thenAnswer(
          (_) async => txSeen
              ? _testWalletTx(txId: 'payjoin-txid', walletId: 'w1')
              : null,
        );

        final repo = buildRepository();
        unawaited(repo.resumePayjoinsOnStartup());
        async.flushMicrotasks();

        final emitted = <Payjoin>[];
        repo.payjoinStream.listen(emitted.add);

        // The expired marker was persisted...
        verify(
          () => localDatasource.update(
            any(that: predicate<PayjoinModel>((m) => m.isExpired)),
          ),
        ).called(greaterThanOrEqualTo(1));

        // ...but the re-armed broadcast watcher still completes the session
        // once the payjoin transaction becomes visible.
        txSeen = true;
        async.elapse(PayjoinRepositoryImpl.broadcastPollInitialDelay);
        async.flushMicrotasks();

        expect(
          emitted.any((p) => p.isCompleted),
          isTrue,
          reason:
              'the expired-else branch must re-arm _watchForBroadcast so '
              'a proposal that lands after expiry still completes',
        );
      });
    });
  });

  group('payjoin labeling on the real completion paths', () {
    // The payjoin system label must mean "this payment actually got
    // CoinJoin-style privacy". Only RECEIVER labeling is ported here: the
    // sender-side path needs FFI BitcoinTx.fromPsbt on a signed psbt, which
    // isn't practical to construct in a unit test (the work tree keeps its
    // own labelCompletedPayjoinSend group above for the sender label).
    test('labels the receiver payjoin tx once it is seen on-chain '
        '(_onPayjoinTransactionSeen)', () async {
      final syncController = StreamController<Wallet>.broadcast();
      addTearDown(syncController.close);
      when(
        () => walletRepository.walletSyncFinishedStream,
      ).thenAnswer((_) => syncController.stream);
      when(
        () => labelsFacade.store(any()),
      ).thenAnswer((_) async => Ok<Label, LabelFailure>(_MockLabel()));

      final model = _receiverModel(
        id: 'pj1',
        walletId: 'w1',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        txId: 'payjoin-txid',
        expireAfterSec: 9999999999,
      );
      when(
        () => localDatasource.fetchAll(onlyUnfinished: true),
      ).thenAnswer((_) async => [model]);
      when(
        () => localDatasource.fetchReceiver('pj1'),
      ).thenAnswer((_) async => model);
      when(
        () => walletTransactionRepository.getWalletTransaction(
          'payjoin-txid',
          walletId: 'w1',
        ),
      ).thenAnswer(
        (_) async => _testWalletTx(txId: 'payjoin-txid', walletId: 'w1'),
      );

      final repo = buildRepository();
      addTearDown(repo.dispose);
      await repo.resumePayjoinsOnStartup();

      syncController.add(_testWallet(origin: 'w1'));
      await Future<void>.delayed(Duration.zero);

      final stored =
          verify(() => labelsFacade.store(captureAny())).captured.single
              as NewLabel;
      expect(stored.type, LabelType.transaction);
      expect(stored.reference, 'payjoin-txid');
      expect(stored.label, LabelSystem.payjoin.label);
      expect(stored.origin, 'w1');
    });
  });
}
