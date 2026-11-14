import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:swaps/swaps.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class VerifyChainSwapAmountSendUsecase {
  final WalletRepository _walletRepository;

  VerifyChainSwapAmountSendUsecase({required this._walletRepository});

  /// Checks that [psbtOrPset] pays exactly the lockup of a send-side swap
  /// ([ChainSwap] or [LnSendSwap]) to its lockup address.
  Future<void> execute({
    required String psbtOrPset,
    required Swap swap,
    required String walletId,
  }) async {
    final (lockupAddress, lockupAmount) = switch (swap) {
      ChainSwap(:final paymentAddress, :final paymentAmount) ||
      LnSendSwap(
        :final paymentAddress,
        :final paymentAmount,
      ) => (paymentAddress, paymentAmount),
      LnReceiveSwap() => throw SwapCreationException(
        'A receive swap has no lockup to verify',
      ),
    };
    try {
      final actualAmount = await _walletRepository.getAmountSentToAddress(
        psbtOrPset: psbtOrPset,
        address: lockupAddress,
        walletId: walletId,
      );

      if (actualAmount != lockupAmount) {
        final error = SwapCreationException(
          'Amount mismatch: expected $lockupAmount sats, but transaction sends $actualAmount sats to swap address',
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
