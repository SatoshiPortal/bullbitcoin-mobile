import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';

class GetWalletTransactionsUsecase {
  final SettingsRepository _settingsRepository;
  final WalletTransactionRepository _walletTransactionRepository;
  final SwapRepository _testnetSwapRepository;
  final SwapRepository _mainnetSwapRepository;

  GetWalletTransactionsUsecase({
    required SettingsRepository settingsRepository,
    required WalletTransactionRepository walletTransactionRepository,
    required SwapRepository testnetSwapRepository,
    required SwapRepository mainnetSwapRepository,
  })  : _settingsRepository = settingsRepository,
        _walletTransactionRepository = walletTransactionRepository,
        _testnetSwapRepository = testnetSwapRepository,
        _mainnetSwapRepository = mainnetSwapRepository;

  Future<List<Transaction>> execute({
    String? walletId,
    bool sync = false,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final walletTransactions =
          await _walletTransactionRepository.getWalletTransactions(
        walletId: walletId,
        sync: sync,
        environment: environment,
      );

      // TODO: We should not fetch the detailed transactions in this use case,
      // This use case should be scoped to the WalletTransaction repository.
      // We should make another or other use cases to fetch more detailes from
      // the transactions.
      final detailedTransactions = <Transaction>[];

      final swapRepository = environment.isTestnet
          ? _testnetSwapRepository
          : _mainnetSwapRepository;

      for (final walletTransaction in walletTransactions) {
        final isLiquid = walletTransaction is LiquidWalletTransaction;
        final network = Network.fromEnvironment(
          isTestnet: environment.isTestnet,
          isLiquid: isLiquid,
        );
        final swapTx = await swapRepository.getSwapWalletTx(
          baseWalletTx: walletTransaction,
          network: network,
        );
        // TODO: check if transaction is a payjoin
        if (swapTx != null) {
          detailedTransactions.add(swapTx);
        } else {
          detailedTransactions.add(
            OnchainTransactionFactory.fromWalletTx(
              walletTransaction,
              network,
            ),
          );
        }
      }

      return detailedTransactions;
    } catch (e) {
      throw GetTransactionsException(e.toString());
    }
  }
}

class GetTransactionsException implements Exception {
  final String message;

  GetTransactionsException(this.message);
}
