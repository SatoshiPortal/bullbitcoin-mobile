import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_has_ongoing_swaps_usecase.dart';

class DeleteWalletUsecase {
  final WalletRepository _walletRepository;
  final CheckWalletHasOngoingSwapsUsecase _checkOngoingSwapsUsecase;

  DeleteWalletUsecase({
    required WalletRepository walletRepository,
    required CheckWalletHasOngoingSwapsUsecase checkOngoingSwapsUsecase,
  }) : _walletRepository = walletRepository,
       _checkOngoingSwapsUsecase = checkOngoingSwapsUsecase;

  Future<void> execute({required String walletId}) async {
    try {
      final wallet = await _walletRepository.getWallet(walletId);
      if (wallet == null) {
        throw WalletNotFoundForDeletionException('Wallet not found');
      }

      // Check if it's a default wallet - default wallets cannot be deleted
      if (wallet.isDefault) {
        throw CannotDeleteDefaultWalletException(
          'Default wallets cannot be deleted',
        );
      }

      // Check if wallet has ongoing swaps
      final hasOngoingSwaps = await _checkOngoingSwapsUsecase.execute(
        walletId: walletId,
      );
      if (hasOngoingSwaps) {
        throw CannotDeleteWalletWithOngoingSwapsException(
          'Cannot delete wallet with ongoing swaps',
        );
      }

      // Proceed with deletion
      await _walletRepository.deleteWallet(walletId: walletId);
    } catch (e) {
      if (e is WalletDeletionException) {
        rethrow;
      }
      throw DeleteWalletException('$e');
    }
  }
}

abstract class WalletDeletionException implements Exception {
  final String message;
  WalletDeletionException(this.message);
}

class DeleteWalletException extends WalletDeletionException {
  DeleteWalletException(super.message);
}

class WalletNotFoundForDeletionException extends WalletDeletionException {
  WalletNotFoundForDeletionException(super.message);
}

class CannotDeleteDefaultWalletException extends WalletDeletionException {
  CannotDeleteDefaultWalletException(super.message);
}

class CannotDeleteWalletWithOngoingSwapsException
    extends WalletDeletionException {
  CannotDeleteWalletWithOngoingSwapsException(super.message);
}
