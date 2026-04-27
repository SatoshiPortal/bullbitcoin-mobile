import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';

class DeleteWalletUsecase {
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;

  DeleteWalletUsecase({
    required WalletRepository walletRepository,
    required BoltzSwapRepository swapRepository,
  }) : _walletRepository = walletRepository,
       _swapRepository = swapRepository;

  Future<void> execute({required String walletId}) async {
    try {
      final wallet = await _walletRepository.getWallet(walletId);
      if (wallet == null) {
        throw WalletError.notFound(walletId);
      }

      if (wallet.isDefault) {
        throw const WalletError.cannotDeleteDefaultWallet();
      }

      final ongoingSwaps = await _swapRepository.getOngoingSwaps(
        walletId: walletId,
      );
      if (ongoingSwaps.isNotEmpty) {
        throw const WalletError.cannotDeleteWalletWithOngoingSwaps();
      }

      await _walletRepository.deleteWallet(walletId: walletId);
    } on WalletError {
      rethrow;
    } catch (e) {
      throw WalletError.unexpected('Failed to delete wallet: $e');
    }
  }
}
