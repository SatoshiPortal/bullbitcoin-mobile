import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class VerifyChainSwapAmountSendUsecase {
  final WalletRepository _walletRepository;

  VerifyChainSwapAmountSendUsecase({required WalletRepository walletRepository})
    : _walletRepository = walletRepository;

  Future<void> execute({
    required String psbtOrPset,
    required ChainSwap swap,
    required String walletId,
  }) async {
    try {
      final actualAmount = await _walletRepository.getAmountSentToAddress(
        psbtOrPset: psbtOrPset,
        address: swap.paymentAddress,
        walletId: walletId,
      );

      if (actualAmount != swap.paymentAmount) {
        final error = SwapCreationException(
          'Amount mismatch: expected ${swap.paymentAmount} sats, but transaction sends $actualAmount sats to swap address',
        );
        log.severe(
          message: 'Swap amount verification failed: Amount mismatch',
          error: error,
          trace: StackTrace.current,
        );
        throw error;
      }
    } catch (e) {
      if (e is SwapCreationException) rethrow;
      final error = SwapCreationException('Failed to verify swap amount: $e');
      log.severe(
        message: 'Failed to verify swap amount',
        error: error,
        trace: StackTrace.current,
      );
      throw error;
    }
  }
}
