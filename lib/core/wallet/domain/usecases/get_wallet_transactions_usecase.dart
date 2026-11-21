import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';

class GetWalletTransactionsUsecase {
  final ActiveEnvironmentReader _settingsRepository;
  final WalletTransactionRepository _walletTransactionRepository;

  GetWalletTransactionsUsecase({
    required this._settingsRepository,
    required this._walletTransactionRepository,
  });

  Future<List<WalletTransaction>> execute({
    String? walletId,
    bool sync = false,
  }) async {
    try {
      final environment = (await _settingsRepository.readActiveEnvironment())
          .fold(
            (value) => value,
            (failure) => throw Exception('Preferences read failed'),
          );
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
