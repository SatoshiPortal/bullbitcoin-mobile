import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';

abstract class PayjoinRepository {
  Stream<PayjoinReceiver> get requestsForReceivers;
  Stream<PayjoinSender> get proposalsForSenders;
  Stream<Payjoin> get expiredPayjoins;
  Future<Payjoin?> getPayjoinByTxId(String txId);
  Future<List<Utxo>> getInputsFromOngoingPayjoins();
  Future<PayjoinReceiver> createPayjoinReceiver({
    required String walletId,
    required bool isTestnet,
    required String address,
    required BigInt maxFeeRateSatPerVb,
    int? expireAfterSec,
  });
  Future<PayjoinSender> createPayjoinSender({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  });
  Future<List<Payjoin>> getAll({
    int? offset,
    int? limit,
    //bool? completed,
  });
  Future<PayjoinReceiver> processRequest({
    required String id,
    required FutureOr<bool> Function(Uint8List) hasOwnedInputs,
    required FutureOr<bool> Function(Uint8List) hasReceiverOutput,
    required List<Utxo> unspentUtxos,
    required FutureOr<String> Function(String) processPsbt,
  });
  Future<String> signPsbt({
    required String walletId,
    required String psbt,
  });
  Future<PayjoinSender> broadcastPsbt({
    required String payjoinId,
    required String finalizedPsbt,
    required Network network,
  });
  Future<PayjoinReceiver> broadcastOriginalTransaction({
    required String payjoinId,
    required Uint8List originalTxBytes,
    required Network network,
  });
}
