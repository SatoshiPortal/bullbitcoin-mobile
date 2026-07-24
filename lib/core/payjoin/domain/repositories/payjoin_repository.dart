import 'dart:async';

import 'package:bb_mobile/core/errors/bull_exception.dart';
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

  /// Throws [PayjoinDisabledForCbfException] when [walletId] is currently
  /// synced via Compact Block Filters — see that exception for why.
  Future<PayjoinReceiver> createPayjoinReceiver({
    required String walletId,
    required bool isTestnet,
    required String address,
    required BigInt maxFeeRateSatPerVb,
    required int expireAfterSec,
  });

  /// Throws [PayjoinDisabledForCbfException] when [walletId] is currently
  /// synced via Compact Block Filters — see that exception for why.
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

/// Thrown by [PayjoinRepository.createPayjoinReceiver] /
/// [createPayjoinSender] when starting a *new* Payjoin session is attempted
/// for a wallet synced via Compact Block Filters (bdk-kyoto). CBF cannot yet
/// verify that the counterparty-contributed inputs of a Payjoin proposal
/// aren't unconfirmed/foreign prevouts the way an Electrum server's mempool
/// lookup can (bdk-kyoto#136 tracks adding that check) — until it's
/// validated, creating a Payjoin under CBF risks silently accepting a
/// proposal BDK can't fully verify.
///
/// Scoped to session *creation* only: a Payjoin already created while the
/// wallet was on Electrum keeps running (proposal processing, broadcast
/// fallback) even if the user switches the wallet to CBF afterwards.
///
/// The message is a fixed, generic string — never derived from the wallet's
/// descriptor, prevouts, or any other sensitive/identifying data.
class PayjoinDisabledForCbfException extends BullException {
  PayjoinDisabledForCbfException()
    : super(
        'Payjoin is not available for wallets using the Compact Block '
        'Filters sync backend yet.',
      );
}
