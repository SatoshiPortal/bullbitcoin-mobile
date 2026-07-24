import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/unconfirmed_bitcoin_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';

/// Records a just-broadcast, wallet-owned outgoing Bitcoin transaction so a
/// CBF wallet's local BDK state reflects it immediately, without waiting
/// for the next sync. Thin orchestration only — every routing/no-op
/// decision (missing wallet, non-Bitcoin, Electrum backend) lives in
/// [UnconfirmedBitcoinTransactionRepository].
///
/// Callers (`BroadcastBitcoinTransactionUsecase`, `PayjoinRepositoryImpl`)
/// treat this as best-effort: an already-successful network broadcast must
/// never be turned into a failure by a local persistence error, so every
/// caller logs and swallows an [Err] rather than propagating it.
class RecordUnconfirmedBitcoinTransactionUsecase {
  final UnconfirmedBitcoinTransactionRepository
  _unconfirmedBitcoinTransactionRepository;

  RecordUnconfirmedBitcoinTransactionUsecase({
    required this._unconfirmedBitcoinTransactionRepository,
  });

  Future<Result<void, WalletSyncFailure>> execute({
    required String walletId,
    required String transaction,
    required bool isPsbt,
  }) => _unconfirmedBitcoinTransactionRepository.record(
    walletId: walletId,
    transaction: transaction,
    isPsbt: isPsbt,
  );
}
