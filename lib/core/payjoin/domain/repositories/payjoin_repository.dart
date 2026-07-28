import 'dart:async';

import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

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

  /// Stops receivers that have not committed a proposal yet.
  Future<void> disableReceivers();

  /// Resumes polling/watching for every unfinished payjoin session left over
  /// from a previous app run. A composition-root lifecycle hook: the
  /// repository is constructed as an eager singleton before every dependency
  /// it needs (wallet repositories, the labels facade) is registered, so this
  /// must be called explicitly once every core dependency it needs is
  /// registered, rather than fired from the constructor — see AppLocator.setup.
  Future<void> resumePayjoinsOnStartup();
}
