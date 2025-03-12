import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/_core/data/datasources/bdk_blockchain_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/payjoin/payjoin_data_source.dart';
import 'package:bb_mobile/_core/data/models/electrum_server_model.dart';
import 'package:bb_mobile/_core/data/models/payjoin_input_pair_model.dart';
import 'package:bb_mobile/_core/domain/entities/electrum_server.dart';
import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/entities/utxo.dart';
import 'package:bb_mobile/_core/domain/repositories/payjoin_repository.dart';

class PayjoinRepositoryImpl implements PayjoinRepository {
  final PayjoinDataSource _source;

  PayjoinRepositoryImpl({
    required PayjoinDataSource payjoinDataSource,
  }) : _source = payjoinDataSource;

  @override
  Stream<PayjoinReceiver> get requestsForReceivers =>
      _source.requestsForReceivers.map(
        (payjoinModel) => payjoinModel.toEntity() as PayjoinReceiver,
      );
  @override
  Stream<PayjoinSender> get proposalsForSenders =>
      _source.proposalsForSenders.map(
        (payjoinModel) => payjoinModel.toEntity() as PayjoinSender,
      );

  @override
  Future<PayjoinReceiver> createPayjoinReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    int? expireAfterSec,
  }) async {
    final model = await _source.createReceiver(
      walletId: walletId,
      address: address,
      isTestnet: isTestnet,
      maxFeeRateSatPerVb: maxFeeRateSatPerVb,
      expireAfterSec: expireAfterSec,
    );

    final payjoin = model.toEntity();

    return payjoin as PayjoinReceiver;
  }

  @override
  Future<PayjoinSender> createPayjoinSender({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  }) async {
    // Create the payjoin sender session
    final model = await _source.createSender(
      walletId: walletId,
      bip21: bip21,
      originalPsbt: originalPsbt,
      networkFeesSatPerVb: networkFeesSatPerVb,
    );

    // Return a payjoin entity with send details
    final payjoin = model.toEntity();

    return payjoin as PayjoinSender;
  }

  @override
  Future<List<Payjoin>> getAll({
    int? offset,
    int? limit,
    bool? completed,
  }) async {
    final models = await _source.getAll();

    final payjoins = models
        .map(
          (model) => model.toEntity(),
        )
        .toList();

    return payjoins;
  }

  @override
  Future<PayjoinReceiver> processRequest({
    required String id,
    required FutureOr<bool> Function(Uint8List) hasOwnedInputs,
    required FutureOr<bool> Function(Uint8List) hasReceiverOutput,
    required List<Utxo> unspentUtxos,
    required FutureOr<String> Function(String) processPsbt,
  }) async {
    final pdkInputPairs = unspentUtxos
        .map((utxo) => PayjoinInputPairModel.fromUtxo(utxo))
        .toList();

    final model = await _source.processRequest(
      id: id,
      hasOwnedInputs: hasOwnedInputs,
      hasReceiverOutput: hasReceiverOutput,
      inputPairs: pdkInputPairs,
      processPsbt: processPsbt,
    );

    return model.toEntity() as PayjoinReceiver;
  }

  @override
  Future<PayjoinSender> broadcastPsbt({
    required String payjoinId,
    required String finalizedPsbt,
    required ElectrumServer electrumServer,
  }) async {
    final blockchain = await BdkBlockchainDataSourceImpl.fromElectrumServer(
      ElectrumServerModel.fromEntity(electrumServer),
    );

    final txId = await blockchain.broadcastPsbt(finalizedPsbt);

    final model = await _source.completeSender(
      payjoinId,
      txId: txId,
    );

    return model.toEntity() as PayjoinSender;
  }
}
