import 'package:primitives/primitives.dart';
import '../repositories/wallet_transaction_repository.dart';
import '../requests/lookup_local_transaction_request.dart';
import '../entities/wallet_transaction_observation.dart';
import '../wallet_transaction_sync_failure.dart';

class LookupLocalTransactionUsecase {
  final WalletTransactionRepository repository;
  const LookupLocalTransactionUsecase(this.repository);
  Future<Result<WalletTransactionObservation?, WalletTransactionSyncFailure>>
  execute(LookupLocalTransactionRequest request) => repository.lookup(request);
}
