import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/pdk_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/payjoin/data/repository/payjoin_repository_impl.dart';
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
}
