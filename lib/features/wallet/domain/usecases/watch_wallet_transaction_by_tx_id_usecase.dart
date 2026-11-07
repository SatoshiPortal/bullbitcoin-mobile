import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';

class WatchWalletTransactionByTxIdUsecase {
  final WalletTransactionRepository _walletTransactionRepository;
  final WalletFacade _walletFacade;

  const WatchWalletTransactionByTxIdUsecase({
    required this._walletTransactionRepository,
    required this._walletFacade,
  });

  Stream<WalletTransaction> execute({
    required String walletId,
    required String txId,
  }) => _walletFacade
      .watchRevisions(walletId: walletId)
      .asyncMap((_) async {
        try {
          return await _walletTransactionRepository.getWalletTransaction(
            txId,
            walletId: walletId,
          );
        } on Exception catch (error) {
          log.warning(
            'Wallet transaction revision read unavailable category=${error.runtimeType}',
          );
          return null;
        }
      })
      .where((transaction) => transaction != null)
      .cast<WalletTransaction>();
}
