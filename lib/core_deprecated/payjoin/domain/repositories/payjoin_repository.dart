import 'dart:async';

import 'package:bb_mobile/core_deprecated/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';

abstract class PayjoinRepository {
  Stream<Payjoin> get payjoinStream;
  Future<bool> checkOhttpRelayHealth();
  Future<List<Payjoin>> getPayjoins({
    String? walletId,
    bool onlyOngoing = false,
    Environment? environment,
  });
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
    required int amountSat,
    required double networkFeesSatPerVb,
    required int expireAfterSec,
  });
  Future<Payjoin?> tryBroadcastOriginalTransaction(Payjoin payjoin);
}
