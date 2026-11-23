import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:sync/sync.dart' show WalletKey;

/// Signs the reviewed spend, then gives the engine a write-ahead admission
/// that can be exercised only with the same wallet, network and transaction.
@useResult
Future<Result<PreparedPayjoinOriginal, SpendFailure>> preparePayjoinOriginal({
  required Spend spend,
  required PreparedBitcoinSpend prepared,
  required String walletId,
  required BitcoinNetwork network,
}) async {
  final signed = await spend.signBitcoin(prepared: prepared);
  return signed.map((value) {
    final psbt = value.signedTransaction;
    return PreparedPayjoinOriginal(
      signedPsbt: psbt,
      admit: ({required sessionId, required persist}) async =>
          (await spend.handOffToPayjoin(
                prepared,
                wallet: WalletKey(id: walletId, network: network),
                sessionId: sessionId,
                signedPsbt: psbt,
                persist: persist,
              ))
              .map((_) {})
              .mapErr(
                (failure) => PayjoinSpendBlockedFailure(
                  busy: failure is SpendUnavailableFailure && failure.busy,
                ),
              ),
    );
  });
}
