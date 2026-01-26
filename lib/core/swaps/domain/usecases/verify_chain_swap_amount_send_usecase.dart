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
        log.severe(
          'Amount mismatch: expected ${swap.paymentAmount}, actual $actualAmount',
          trace: StackTrace.current,
        );
        throw SwapCreationException(
          'Amount mismatch: expected ${swap.paymentAmount} sats, but transaction sends $actualAmount sats to swap address',
        );
      }
    } catch (e) {
      if (e is SwapCreationException) {
        rethrow;
      }
      log.severe('Error verifying swap amount: $e', trace: StackTrace.current);
      throw SwapCreationException('Failed to verify swap amount: $e');
    }
  }
}
