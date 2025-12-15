import 'package:bb_mobile/features/wallets/application/ports/wallets_repository_port.dart';
import 'package:bb_mobile/features/wallets/domain/entities/wallet_entity.dart';
import 'package:bb_mobile/features/wallets/domain/entities/wallet_transaction_entity.dart';
import 'package:bb_mobile/features/wallets/driven_adapters/wallets/wallet_port_registry.dart';

class TransactionAggregatorService {
  final WalletPortRegistry _registry;
  final WalletsRepositoryPort _walletsRepository;

  TransactionAggregatorService({
    required WalletPortRegistry registry,
    required WalletsRepositoryPort walletsRepository,
  }) : _registry = registry,
       _walletsRepository = walletsRepository;

  Future<List<WalletTransactionEntity>> getMainnetTransactions() async {
    final wallets = await _walletsRepository.getMainnetWallets();

    return _getWalletsTransactions(wallets);
  }

  Future<List<WalletTransactionEntity>> getTestnetTransactions() async {
    final wallets = await _walletsRepository.getTestnetWallets();

    return _getWalletsTransactions(wallets);
  }

  Future<List<WalletTransactionEntity>> _getWalletsTransactions(
    List<WalletEntity> wallets,
  ) async {
    // Fetch transactions for each wallet using the appropriate port
    final results = await Future.wait(
      wallets.map((wallet) {
        final port = _registry.getPort(wallet.network);
        return port.getTransactions(wallet.id!);
      }),
    );

    // Flatten and sort all transactions
    final allTransactions = results.expand((txs) => txs).toList();
    allTransactions.sort((a, b) {
      // Unconfirmed transactions (null confirmationTime) come first
      if (a.confirmationTime == null && b.confirmationTime == null) return 0;
      if (a.confirmationTime == null) return -1;
      if (b.confirmationTime == null) return 1;
      // Then sort by most recent confirmationTime
      return b.confirmationTime!.compareTo(a.confirmationTime!);
    });

    return allTransactions;
  }
}
