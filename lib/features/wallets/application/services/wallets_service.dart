import 'package:bb_mobile/features/wallets/application/ports/wallet_port.dart';
import 'package:bb_mobile/features/wallets/application/ports/wallets_repository_port.dart';
import 'package:bb_mobile/features/wallets/domain/entities/wallet_transaction_entity.dart';
import 'package:bb_mobile/features/wallets/domain/value_objects/wallet_output_vo.dart';
import 'package:bb_mobile/features/wallets/domain/value_objects/wallet_balance_vo.dart';
import 'package:bb_mobile/features/wallets/driven_adapters/wallets/wallet_port_registry.dart';

class WalletsService {
  final WalletPortRegistry _registry;
  final WalletsRepositoryPort _walletsRepository;

  WalletsService({
    required WalletPortRegistry registry,
    required WalletsRepositoryPort walletsRepository,
  }) : _registry = registry,
       _walletsRepository = walletsRepository;

  Future<WalletBalanceVO> getBalance(int walletId) async {
    final port = await _getPortForWalletId(walletId);
    final balance = await port.getBalance(walletId);

    return balance;
  }

  Future<List<WalletTransactionEntity>> getTransactions(int walletId) async {
    final port = await _getPortForWalletId(walletId);
    final transactions = await port.getTransactions(walletId);

    transactions.sort((a, b) {
      // Unconfirmed transactions (null confirmationTime) come first
      if (a.confirmationTime == null && b.confirmationTime == null) return 0;
      if (a.confirmationTime == null) return -1;
      if (b.confirmationTime == null) return 1;
      // Then sort by most recent confirmationTime
      return b.confirmationTime!.compareTo(a.confirmationTime!);
    });

    return transactions;
  }

  Future<List<WalletOutputVO>> getUnspentOutputs(int walletId) async {
    final port = await _getPortForWalletId(walletId);
    final unspentOutputs = await port.getUnspentOutputs(walletId);

    return unspentOutputs;
  }

  Future<WalletPort> _getPortForWalletId(int walletId) async {
    final wallet = await _walletsRepository.getWalletById(walletId);
    final port = _registry.getPort(wallet.network);
    return port;
  }
}
