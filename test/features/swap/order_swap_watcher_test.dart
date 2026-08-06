import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_pending_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/order_swap_watcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRefreshOrderSwapsUsecase extends Mock
    implements RefreshOrderSwapsUsecase {}

void main() {
  test('deduplicates overlapping refresh requests', () async {
    final usecase = _MockRefreshOrderSwapsUsecase();
    final completion = Completer<Result<OrderSwapRefreshBatch, SwapFailure>>();
    when(usecase.execute).thenAnswer((_) => completion.future);
    final watcher = OrderSwapWatcher(usecase);

    final first = watcher.refresh();
    final second = watcher.refresh();
    await Future<void>.delayed(Duration.zero);

    verify(usecase.execute).called(1);
    completion.complete(
      const Ok(
        OrderSwapRefreshBatch(
          pollableOrderCount: 0,
          refreshed: [],
          failures: [],
        ),
      ),
    );
    await Future.wait([first, second]);
    watcher.dispose();
  });
}
