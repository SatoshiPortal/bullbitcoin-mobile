import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/verify_swap_lockup.dart';
import 'package:test/test.dart';

void main() {
  test('reports a decoder StateError without exposing its details', () async {
    final swap = Swap.lnSend(
      id: 'send-swap',
      keyIndex: 0,
      type: SwapType.bitcoinToLightning,
      status: SwapStatus.pending,
      environment: Environment.mainnet,
      creationTime: DateTime.utc(2026),
      sendWalletId: 'wallet',
      invoice: 'lnbc1',
      paymentAddress: 'bc1plockup',
      paymentAmount: 51000,
    );

    final result = await verifySwapLockup(
      swap,
      amountTo: (_) async => throw StateError('private decoder detail'),
    );

    expect(
      result,
      isA<Err<void, SwapsInvalidLockupFailure>>()
          .having(
            (result) => result.failure.issue,
            'issue',
            SwapLockupIssue.unreadable,
          )
          .having(
            (result) => result.failure.logMessage,
            'logMessage',
            'StateError',
          ),
    );
  });
}
