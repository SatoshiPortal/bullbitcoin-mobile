import 'dart:async';

import 'package:bb_mobile/_core/data/datasources/bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/_core/data/datasources/payjoin_datasource.dart';
import 'package:bb_mobile/_core/data/models/electrum_server_model.dart';
import 'package:bb_mobile/_core/data/models/payjoin_input_pair_model.dart';
import 'package:bb_mobile/_core/data/models/payjoin_model.dart';
import 'package:bb_mobile/_core/domain/entities/electrum_server.dart';
import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/entities/tx_input.dart';
import 'package:bb_mobile/_core/domain/entities/utxo.dart';
import 'package:bb_mobile/_core/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/_utils/transaction_parsing.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

class PayjoinRepositoryImpl implements PayjoinRepository {
  final PayjoinDatasource _source;
  // Lock to prevent the same utxo from being used in multiple payjoin proposals
  final Lock _lock;

  PayjoinRepositoryImpl({
    required PayjoinDatasource payjoinDatasource,
  })  : _source = payjoinDatasource,
        _lock = Lock();

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
  Future<List<TxInput>> getInputsFromOngoingPayjoins() async {
    final inputs = <TxInput>[];
    final payjoins = await _source.getAll();
    for (final payjoin in payjoins) {
      String? psbt;
      switch (payjoin) {
        case final PayjoinReceiverModel receiver:
          psbt = receiver.proposalPsbt;
          debugPrint('ongoing receiver with psbt: $psbt');
        case final PayjoinSenderModel sender:
          psbt = sender.originalPsbt;
          debugPrint('ongoing sender with psbt: $psbt');
      }
      if (psbt != null) {
        // Extract the inputs from the proposal psbt
        final psbtInputs = await TransactionParsing.extractInputsFromPsbt(psbt);
        debugPrint('extracted inputs $psbtInputs, for psbt: $psbt');
        inputs.addAll(psbtInputs);
      }
    }

    debugPrint('ongoingPayjoins: $payjoins');
    debugPrint('inputsFromOngoingPayjoins: $inputs');

    return inputs;
  }

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
    // A lock is needed here to make sure the proposal of a payjoin is stored
    //  before another payjoin checks for available inputs to create a proposal
    final payjoinReceiver = await _lock.synchronized(() async {
      debugPrint('unspentUtxos: $unspentUtxos');
      // Make sure the inputs to select from for the proposal are not used by
      //  ongoing payjoins already
      final lockedInputs = await getInputsFromOngoingPayjoins();
      debugPrint('lockedInputs: $lockedInputs');

      final pdkInputPairs = unspentUtxos
          .where((utxo) {
            final isUtxoLocked = lockedInputs.any((input) {
              return input.txId == utxo.txId && input.vout == utxo.vout;
            });

            return !isUtxoLocked;
          })
          .map((utxo) => PayjoinInputPairModel.fromUtxo(utxo))
          .toList();

      debugPrint('pdkInputPairs: $pdkInputPairs');

      if (pdkInputPairs.isEmpty) {
        throw const NoInputsToPayjoinException(
          message: 'No inputs available to create a new payjoin proposal',
        );
      }

      final model = await _source.processRequest(
        id: id,
        hasOwnedInputs: hasOwnedInputs,
        hasReceiverOutput: hasReceiverOutput,
        inputPairs: pdkInputPairs,
        processPsbt: processPsbt,
      );

      return model.toEntity() as PayjoinReceiver;
    });

    return payjoinReceiver;
  }

  @override
  Future<PayjoinSender> broadcastPsbt({
    required String payjoinId,
    required String finalizedPsbt,
    required ElectrumServer electrumServer,
  }) async {
    final blockchain = await BdkBlockchainDatasourceImpl.fromElectrumServer(
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

class NoInputsToPayjoinException implements Exception {
  final String? message;

  const NoInputsToPayjoinException({this.message});
}
