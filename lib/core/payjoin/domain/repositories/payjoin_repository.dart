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

  /// [amountSat] pins the amount inside the generated BIP21 URI, for callers
  /// that know it upfront and cannot revise the URI later. Left null, the URI
  /// carries no amount and the caller composes one.
  Future<PayjoinReceiver> createPayjoinReceiver({
    required String walletId,
    required bool isTestnet,
    required String address,
    required BigInt maxFeeRateSatPerVb,
    required int expireAfterSec,
    int? amountSat,
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

  /// Abandons a single receiver session on the user's behalf, settling it the
  /// same way a global disable would.
  ///
  /// An idle session is simply dropped. One already holding the sender's
  /// original transaction is declined and that transaction is broadcast, so the
  /// payment still lands as a plain send. One that already sent a proposal is
  /// left alone and watched: the sender owns the outcome from that point.
  ///
  /// Does nothing when the session is unknown or already terminal.
  Future<void> cancelReceiver(String payjoinId);

  /// Stops receivers that have not committed a proposal yet.
  Future<void> disableReceivers();

  /// Resumes polling/watching for every unfinished payjoin session left over
  /// from a previous app run. The foreground composition root calls this
  /// explicitly after dependency registration; background locators must not
  /// start protocol work.
  Future<void> resumePayjoinsOnStartup();
}
