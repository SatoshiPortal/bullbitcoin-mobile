import 'dart:async';

import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_kind.dart';
import 'package:bb_mobile/features/swap/order_swap_watcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSyncCoordinator extends Mock implements SyncCoordinator {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deduplicates overlapping refresh requests', () async {
    final coordinator = _MockSyncCoordinator();
    final completion = Completer<void>();
    when(
      () => coordinator.sync(only: {SyncKind.swaps}),
    ).thenAnswer((_) => completion.future);
    final watcher = OrderSwapWatcher(coordinator);

    final first = watcher.refresh();
    final second = watcher.refresh();
    await Future<void>.delayed(Duration.zero);

    verify(() => coordinator.sync(only: {SyncKind.swaps})).called(1);
    completion.complete();
    await Future.wait([first, second]);
    watcher.dispose();
  });
}
