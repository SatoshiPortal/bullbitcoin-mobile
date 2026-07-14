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
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
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

class _MockLabel extends Mock implements Label {}

class _FakeNewLabel extends Fake implements NewLabel {}

PayjoinReceiverModel _receiverModel({
  String id = 'pj1',
  String walletId = 'w1',
  String? originalTxId = 'orig-txid',
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
        expireAfterSec: 300,
        originalTxBytes: Uint8List.fromList([1, 2, 3]),
        originalTxId: originalTxId,
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
  });

  setUp(() {
    local = _MockLocalPayjoinDatasource();
    pdk = _MockPdkPayjoinDatasource();
    blockchain = _MockBdkBitcoinBlockchainDatasource();
    serversPort = _MockElectrumServersPort();
    labels = _MockLabelsFacade();

    // The constructor wires up datasource stream listeners and kicks off
    // _resumePayjoins(); stub them so construction is inert in the test.
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
      labelsFacade: () => labels,
    );
  });

  group('tryBroadcastOriginalTransaction labels the completed payjoin', () {
    test('tags the original txid with the payjoin system label', () async {
      final model = _receiverModel(originalTxId: 'orig-txid');
      when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);
      when(
        () => labels.store(any()),
      ).thenAnswer((_) async => Ok<Label, LabelFailure>(_MockLabel()));

      await repository.tryBroadcastOriginalTransaction(model.toEntity());

      final captured =
          verify(() => labels.store(captureAny())).captured.single as NewLabel;
      expect(captured.label, LabelSystem.payjoin.label);
      expect(captured.type, LabelType.transaction);
      // The tx that actually landed on-chain is the ORIGINAL one.
      expect(captured.reference, 'orig-txid');
      expect(captured.origin, 'w1');
    });

    test('does not label when the original txid is unknown', () async {
      final model = _receiverModel(originalTxId: null);
      when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);

      await repository.tryBroadcastOriginalTransaction(model.toEntity());

      verifyNever(() => labels.store(any()));
    });

    test('a labelling failure does not fail the broadcast', () async {
      final model = _receiverModel(originalTxId: 'orig-txid');
      when(() => local.fetchReceiver('pj1')).thenAnswer((_) async => model);
      when(() => labels.store(any())).thenAnswer(
        (_) async => const Err<Label, LabelFailure>(LabelUnexpectedFailure()),
      );

      final result = await repository.tryBroadcastOriginalTransaction(
        model.toEntity(),
      );

      // Best-effort labelling: the (already broadcast) payjoin still completes.
      expect(result, isNotNull);
    });
  });

  group('tryBroadcastOriginalTransaction sender fallback (#2246)', () {
    test('broadcasts the sender original psbt and completes', () async {
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
      // The original tx gets labelled as payjoin for traceability.
      final captured =
          verify(() => labels.store(captureAny())).captured.single as NewLabel;
      expect(captured.label, LabelSystem.payjoin.label);
      expect(captured.reference, 'sender-orig-txid');
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
}
