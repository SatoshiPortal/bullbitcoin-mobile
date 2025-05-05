import 'dart:async';

import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';

abstract class PayjoinRepository {
  Stream<Payjoin> get payjoinStream;
  Future<bool> checkOhttpRelayHealth();
  Future<List<Payjoin>> getPayjoins({bool onlyOngoing = false});
  Future<Payjoin?> getPayjoinById(String payjoinId);
  Future<List<Payjoin>> getPayjoinsByTxId(String txId);
  Future<List<({String txId, int vout})>> getUtxosFrozenByOngoingPayjoins();
  Future<PayjoinReceiver> createPayjoinReceiver({
    required String walletId,
    required bool isTestnet,
    required String address,
    required BigInt maxFeeRateSatPerVb,
    required int expireAfterSec,
  });
  Future<PayjoinSender> createPayjoinSender({
    required String walletId,
    required bool isTestnet,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
    required int expireAfterSec,
  });
  Future<PayjoinReceiver?> tryBroadcastOriginalTransaction(
    PayjoinReceiver payjoinReceiver,
  );
}
