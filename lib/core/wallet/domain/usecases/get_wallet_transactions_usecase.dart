import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';

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
      final (broadcastedTransactions, ongoingPayjoinTransactions) =
          await (
            _walletTransactionRepository.getBroadcastedWalletTransactions(
              walletId: walletId,
              sync: sync,
              environment: environment,
            ),
            _walletTransactionRepository.getOngoingPayjoinWalletTransactions(
              walletId: walletId,
              sync: sync,
              environment: environment,
            ),
          ).wait;

      final walletTransactions = [
        ...broadcastedTransactions,
        ...ongoingPayjoinTransactions,
      ];

      return walletTransactions;
    } catch (e) {
      throw GetWalletTransactionsException(e.toString());
    }
  }
}

class GetWalletTransactionsException implements Exception {
  final String message;

  GetWalletTransactionsException(this.message);
}
