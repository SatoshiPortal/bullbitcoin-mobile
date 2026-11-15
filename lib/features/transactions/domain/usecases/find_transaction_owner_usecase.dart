import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

class FindTransactionOwnerUsecase {
  final SettingsRepository _settingsRepository;
  final WalletTransactionRepository _walletTransactionRepository;
  final GetWalletUsecase _getWalletUsecase;

  const FindTransactionOwnerUsecase({
    required this._settingsRepository,
    required this._walletTransactionRepository,
    required this._getWalletUsecase,
  });

  @useResult
  Future<Result<Wallet?, TransactionFailure>> execute(String txid) async {
    try {
      final settings = await _settingsRepository.fetch();
      final transactions = await _walletTransactionRepository
          .getWalletTransactions(
            txId: txid.trim().toLowerCase(),
            environment: settings.environment,
          );
      for (final transaction in transactions) {
        final wallet = await _getWalletUsecase.execute(transaction.walletId);
        if (wallet != null) return Ok(wallet);
      }
      return const Ok(null);
    } catch (e) {
      log.warning(
        'Transaction explorer: ownership check failed (${e.runtimeType})',
      );
      return Err(TransactionUnexpectedFailure('owner: ${e.runtimeType}'));
    }
  }
}
