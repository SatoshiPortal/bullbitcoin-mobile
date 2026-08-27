import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';

class OrderSwapRefreshBatch {
  final int pollableOrderCount;
  final List<OrderSwapRecord> refreshed;
  final List<SwapFailure> failures;

  const OrderSwapRefreshBatch({
    required this.pollableOrderCount,
    required this.refreshed,
    required this.failures,
  });
}

class RefreshPendingOrderSwapsUsecase {
  final OrderSwapRepository _repository;
  final Future<void> Function(Duration) _delay;
  final Duration _requestSpacing;

  RefreshPendingOrderSwapsUsecase(
    this._repository, {
    Future<void> Function(Duration)? delay,
    this._requestSpacing = const Duration(seconds: 30),
  }) : _delay = delay ?? Future<void>.delayed;

  Future<Result<OrderSwapRefreshBatch, SwapFailure>> execute() async {
    final pendingResult = await _repository.getPendingOrders();
    final List<OrderSwapRecord> pending;
    switch (pendingResult) {
      case Ok(:final value):
        pending = value;
      case Err(:final failure):
        return Err(failure);
    }
    // Preserve legacy Funding rows without repeatedly polling their invalid ids.
    final pollable = pending
        .where(
          (record) =>
              record.orderId != null && record.order?.orderType != 'Funding',
        )
        .toList();
    final refreshed = <OrderSwapRecord>[];
    final failures = <SwapFailure>[];

    for (final (index, record) in pollable.indexed) {
      if (index > 0) await _delay(_requestSpacing);
      switch (await _repository.refreshOrder(record.localId)) {
        case Ok(:final value):
          refreshed.add(value);
        case Err(:final failure):
          failures.add(failure);
          if (failure is SwapRateLimitedFailure) {
            return Ok(
              OrderSwapRefreshBatch(
                pollableOrderCount: pollable.length,
                refreshed: refreshed,
                failures: failures,
              ),
            );
          }
      }
    }

    return Ok(
      OrderSwapRefreshBatch(
        pollableOrderCount: pollable.length,
        refreshed: refreshed,
        failures: failures,
      ),
    );
  }
}
