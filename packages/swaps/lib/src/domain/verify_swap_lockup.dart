import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'entities/swap.dart';
import 'entities/swap_failure.dart';

/// Checks the exact payout of a send-side swap before admitting a broadcast.
/// The caller supplies the decoder for the actual funding wallet and network.
@useResult
Future<Result<void, SwapsInvalidLockupFailure>> verifySwapLockup(
  Swap swap, {
  required Future<int> Function(String address) amountTo,
}) async {
  final (address, expected) = switch (swap) {
    ChainSwap(:final paymentAddress, :final paymentAmount) ||
    LnSendSwap(
      :final paymentAddress,
      :final paymentAmount,
    ) => (paymentAddress, paymentAmount),
    LnReceiveSwap() => (null, null),
  };
  if (address == null) {
    return const Err(SwapsInvalidLockupFailure(SwapLockupIssue.receiveSwap));
  }
  try {
    final amount = await amountTo(address);
    return amount == expected
        ? const Ok(null)
        : const Err(SwapsInvalidLockupFailure(SwapLockupIssue.amountMismatch));
  } catch (error) {
    // Preserve the legacy lockup check's handling of decoder errors.
    return Err(
      SwapsInvalidLockupFailure(
        SwapLockupIssue.unreadable,
        error.runtimeType.toString(),
      ),
    );
  }
}
