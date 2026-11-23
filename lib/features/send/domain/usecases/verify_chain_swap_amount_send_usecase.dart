import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:swaps/swaps.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';

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
    final result = await verifySwapLockup(
      swap,
      amountTo: (address) => _walletRepository.getAmountSentToAddress(
        psbtOrPset: psbtOrPset,
        address: address,
        walletId: walletId,
      ),
    );
    if (result case Err(failure: final failure)) {
      final issue = failure.issue;
      final logMessage = failure.logMessage;
      final message = switch (issue) {
        SwapLockupIssue.receiveSwap => 'A receive swap has no lockup to verify',
        SwapLockupIssue.amountMismatch => 'Amount mismatch: the transaction does not pay the swap lockup amount',
        SwapLockupIssue.unreadable =>
          'Failed to verify swap amount ($logMessage)',
      };
      final error = SwapCreationException(message);
      log.severe(
        message: 'Failed to verify swap amount',
        error: error,
        trace: StackTrace.current,
      );
      throw error;
    }
  }
}
