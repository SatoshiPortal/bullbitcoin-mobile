import 'package:mocktail/mocktail.dart';
import 'package:swaps/src/domain/swap_watcher.dart';
import 'package:swaps/src/domain/usecases/retry_ongoing_swaps_usecase.dart';
import 'package:test/test.dart';

class _MockSwapWatcher extends Mock implements SwapWatcher {}

void main() {
  test('a manual retry restarts the watcher, clearing its backoffs', () async {
    final watcher = _MockSwapWatcher();
    when(watcher.restart).thenAnswer((_) async {});

    await RetryOngoingSwapsUsecase(watcher).execute();

    verify(watcher.restart).called(1);
  });

  test('a failed restart does not reach the caller', () async {
    final watcher = _MockSwapWatcher();
    when(watcher.restart).thenThrow(StateError('store closed'));

    await RetryOngoingSwapsUsecase(watcher).execute();

    verify(watcher.restart).called(1);
  });
}
