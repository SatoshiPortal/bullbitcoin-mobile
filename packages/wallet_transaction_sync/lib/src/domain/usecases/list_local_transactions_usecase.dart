import 'package:primitives/primitives.dart';
import '../repositories/wallet_transaction_repository.dart';
import '../requests/list_local_transactions_request.dart';
import '../entities/wallet_transaction_page.dart';
import '../wallet_transaction_sync_failure.dart';

class ListLocalTransactionsUsecase {
  final WalletTransactionRepository repository;
  const ListLocalTransactionsUsecase(this.repository);
  Future<Result<WalletTransactionPage, WalletTransactionSyncFailure>> execute(
    ListLocalTransactionsRequest request,
  ) => repository.list(request);
}
