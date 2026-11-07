import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';

class WatchWalletTransactionByAddressUsecase {
  final WalletTransactionRepository _walletTransactionRepository;
  final WalletFacade _walletFacade;

  const WatchWalletTransactionByAddressUsecase({
    required this._walletTransactionRepository,
    required this._walletFacade,
  });

  Stream<WalletTransaction> execute({
    required String walletId,
    required String toAddress,
  }) => _walletFacade
      .watchRevisions(walletId: walletId)
      .asyncMap((_) async {
        try {
          final txs = await _walletTransactionRepository.getWalletTransactions(
            walletId: walletId,
            toAddress: toAddress,
          );
          return txs.isEmpty ? null : txs.last;
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
