import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps active Exchange transfer states to progress states', () {
    expect(
      transferSwapStatusForOrderSwap(OrderSwapLocalStatus.payinBroadcast),
      SwapStatus.paid,
    );
    expect(
      transferSwapStatusForOrderSwap(OrderSwapLocalStatus.payoutInProgress),
      SwapStatus.paid,
    );
    expect(
      transferSwapStatusForOrderSwap(
        OrderSwapLocalStatus.awaitingUserConfirmation,
      ),
      SwapStatus.pending,
    );
  });

  test('maps terminal Exchange transfer states', () {
    expect(
      transferSwapStatusForOrderSwap(OrderSwapLocalStatus.completed),
      SwapStatus.completed,
    );
    expect(
      transferSwapStatusForOrderSwap(OrderSwapLocalStatus.refunded),
      SwapStatus.refunded,
    );
    expect(
      transferSwapStatusForOrderSwap(OrderSwapLocalStatus.expired),
      SwapStatus.expired,
    );
    expect(
      transferSwapStatusForOrderSwap(OrderSwapLocalStatus.failed),
      SwapStatus.failed,
    );
  });
}
