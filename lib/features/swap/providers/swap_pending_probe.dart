import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_swap/bull_swap.dart';

class SwapPendingProbe implements PendingSwapsProbe {
  final OrderSwapRepository _orders;
  final BoltzSwapRepository _boltz;

  SwapPendingProbe(this._orders, this._boltz);

  @override
  Future<bool> hasActiveSwaps() async {
    final orders = await _orders.getPendingOrders();
    final hasPendingOrders = switch (orders) {
      Ok(:final value) => value.isNotEmpty,
      Err() => false,
    };
    if (hasPendingOrders) return true;
    final ongoing = await _boltz.getOngoingSwaps();
    return ongoing.isNotEmpty;
  }
}
