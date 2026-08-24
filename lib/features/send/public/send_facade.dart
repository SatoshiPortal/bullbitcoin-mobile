import 'package:bb_mobile/features/send/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_pending_bitcoin_transactions_usecase.dart';

export '../domain/pending_bitcoin_transaction.dart';
export '../domain/send_failure.dart';
export 'send_route.dart';
export 'send_route_args.dart';

/// Send's published capabilities: the shared broadcast entry point and the
/// verification of an externally signed transaction against its exported PSBT.
///
/// Local Bitcoin broadcast callers must supply the captured wallet identity.
/// Accepted local-record failures retain a live spend barrier.
final class SendFacade {
  final Future<String> Function(
    String, {
    required String walletId,
    required bool isPsbt,
    required Network network,
  })
  _bitcoin;
  final Future<String> Function(String) _liquid;
  final VerifySignedTxUsecase _verifySignedTxUsecase;
  final WatchPendingBitcoinTransactionsUsecase
  _watchPendingBitcoinTransactionsUsecase;

  SendFacade({
    required this._bitcoin,
    required this._liquid,
    VerifySignedTxUsecase? verifySignedTxUsecase,
    required this._watchPendingBitcoinTransactionsUsecase,
  }) : _verifySignedTxUsecase =
           verifySignedTxUsecase ?? VerifySignedTxUsecase();

  Future<String> bitcoin(
    String transaction, {
    required String walletId,
    required bool isPsbt,
    required Network network,
  }) => _bitcoin(
    transaction,
    walletId: walletId,
    isPsbt: isPsbt,
    network: network,
  );
  Future<String> liquid(String transaction) => _liquid(transaction);

  @useResult
  Future<Result<void, SendFailure>> verifySignedTransaction({
    required String unsignedPsbt,
    required String signedTransaction,
    bool isPsbt = false,
  }) => _verifySignedTxUsecase.execute(
    unsignedPsbt: unsignedPsbt,
    signedTransaction: signedTransaction,
    isPsbt: isPsbt,
  );

  Stream<Result<PendingBitcoinTransactionSnapshot, SendFailure>> watchPending(
    String walletId,
  ) => _watchPendingBitcoinTransactionsUsecase.execute(walletId);
}
