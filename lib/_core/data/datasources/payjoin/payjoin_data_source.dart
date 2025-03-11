import 'dart:async';

import 'package:bb_mobile/_core/data/models/pdk_input_pair_model.dart';
import 'package:bb_mobile/_core/data/models/pdk_payjoin_model.dart';
import 'package:flutter/foundation.dart';

abstract class PayjoinDataSource {
  // requestsForReceivers is a stream that emits a PdkPayjoinReceiverModel every
  //  time a payjoin request (original tx psbt) is received from a sender.
  Stream<PdkPayjoinReceiverModel> get requestsForReceivers;
  // proposalsForSenders is a stream that emits a PdkPayjoinSenderModel every time a
  //  payjoin proposal (payjoin tx psbt) was sent by a receiver for a sender.
  Stream<PdkPayjoinSenderModel> get proposalsForSenders;
  Future<PdkPayjoinReceiverModel> createReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    int? expireAfterSec,
  });
  Future<PdkPayjoinSenderModel> createSender({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  });
  Future<PdkPayjoinModel?> get(String id);
  Future<List<PdkPayjoinModel>> getAll();
  Future<void> delete(String id);
  Future<PdkPayjoinReceiverModel> processRequest({
    required String id,
    required FutureOr<bool> Function(Uint8List) hasOwnedInputs,
    required FutureOr<bool> Function(Uint8List) hasReceiverOutput,
    required List<PdkInputPairModel> inputPairs,
    required FutureOr<String> Function(String) processPsbt,
  });
  Future<PdkPayjoinSenderModel> completeSender(
    String uri, {
    required String txId,
  });
}

class PayjoinNotFoundException implements Exception {
  final String message;

  PayjoinNotFoundException(this.message);
}

class ReceiveCreationException implements Exception {
  final String message;

  ReceiveCreationException(this.message);
}

class NoValidPayjoinBip21Exception implements Exception {
  final String message;

  NoValidPayjoinBip21Exception(this.message);
}
