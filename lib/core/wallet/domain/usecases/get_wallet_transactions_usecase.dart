/*import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class GetWalletTransactionsUsecase {
  final WalletRepository _wallet;
  final SwapRepository _testnetSwapRepository;
  final SwapRepository _mainnetSwapRepository;

  GetWalletTransactionsUsecase({
    required WalletRepository walletRepository,
    required SwapRepository testnetSwapRepository,
    required SwapRepository mainnetSwapRepository,
  })  : _manager = walletManager,
        _testnetSwapRepository = testnetSwapRepository,
        _mainnetSwapRepository = mainnetSwapRepository;

  Future<List<WalletTransaction>> execute(String walletId) async {
    final wallet = await _manager.getWallet(walletId);
    if (wallet == null) {
      return [];
    }
    final List<WalletTransaction> allTransactions = [];

    final network = wallet.network;
    final swapRepository =
        network.isTestnet ? _testnetSwapRepository : _mainnetSwapRepository;

    final baseTransactions =
        await _manager.getBaseTransactions(walletId: wallet.id);

    for (final baseWalletTx in baseTransactions) {
      final swapTx = await swapRepository.getSwapWalletTx(
        baseWalletTx: baseWalletTx,
      );
      // TODO: check if transaction is a payjoin
      if (swapTx != null) {
        allTransactions.add(swapTx);
      } else if (baseWalletTx.type == TxType.send) {
        allTransactions.add(
          SendTransactionFactory.fromBaseWalletTx(baseWalletTx),
        );
      } else if (baseWalletTx.type == TxType.receive) {
        allTransactions.add(
          ReceiveTransactionFactory.fromBaseWalletTx(baseWalletTx),
        );
      } else {
        continue;
      }
    }

    return allTransactions;
  }
}
*/
