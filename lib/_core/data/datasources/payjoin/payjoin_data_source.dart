import 'dart:async';

import 'package:bb_mobile/_core/data/models/payjoin_input_pair_model.dart';
import 'package:bb_mobile/_core/data/models/payjoin_model.dart';
import 'package:flutter/foundation.dart';

abstract class PayjoinDataSource {
  // requestsForReceivers is a stream that emits a PayjoinReceiverModel every
  //  time a payjoin request (original tx psbt) is received from a sender.
  Stream<PayjoinReceiverModel> get requestsForReceivers;
  // proposalsForSenders is a stream that emits a PayjoinSenderModel every time a
  //  payjoin proposal (payjoin tx psbt) was sent by a receiver for a sender.
  Stream<PayjoinSenderModel> get proposalsForSenders;
  Future<PayjoinReceiverModel> createReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    int? expireAfterSec,
  });
  Future<PayjoinSenderModel> createSender({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  });
  Future<PayjoinModel?> get(String id);
  Future<List<PayjoinModel>> getAll();
  Future<void> delete(String id);
  Future<PayjoinReceiverModel> processRequest({
    required String id,
    required FutureOr<bool> Function(Uint8List) hasOwnedInputs,
    required FutureOr<bool> Function(Uint8List) hasReceiverOutput,
    required List<PayjoinInputPairModel> inputPairs,
    required FutureOr<String> Function(String) processPsbt,
  });
  Future<PayjoinSenderModel> completeSender(
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
