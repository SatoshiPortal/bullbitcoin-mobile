import 'package:primitives/primitives.dart';
import '../repositories/wallet_transaction_repository.dart';
import '../requests/broadcast_cbf_transaction_request.dart';
import '../wallet_transaction_sync_failure.dart';

final class BroadcastCbfTransactionUsecase {
  final WalletTransactionRepository _repository;

  const BroadcastCbfTransactionUsecase(this._repository);

  Future<Result<String, WalletTransactionSyncFailure>> execute(
    BroadcastCbfTransactionRequest request,
  ) => _repository.broadcastCbf(request);
}
