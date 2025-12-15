import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/repositories/wallet_transaction_repository.dart';

class GetWalletTransactionsUsecase {
  final SettingsRepository _settingsRepository;
  final WalletTransactionRepository _walletTransactionRepository;

  GetWalletTransactionsUsecase({
    required SettingsRepository settingsRepository,
    required WalletTransactionRepository walletTransactionRepository,
  }) : _settingsRepository = settingsRepository,
       _walletTransactionRepository = walletTransactionRepository;

  Future<List<WalletTransaction>> execute({
    String? walletId,
    bool sync = false,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final walletTransactions = await _walletTransactionRepository
          .getWalletTransactions(
            walletId: walletId,
            sync: sync,
            environment: environment,
          );

      return walletTransactions;
    } catch (e) {
      throw GetWalletTransactionsException(e.toString());
    }
  }
}

class GetWalletTransactionsException extends BullException {
  GetWalletTransactionsException(super.message);
}
