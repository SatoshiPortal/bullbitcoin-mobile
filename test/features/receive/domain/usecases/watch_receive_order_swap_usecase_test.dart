import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockSwapFacade extends Mock implements SwapFacade {}

const _rawReason = 'boltz 502: <html>nginx upstream at 10.0.0.7</html>';

void main() {
  test(
    'maps a swap network failure to this feature\'s network failure',
    () async {
      final swaps = _MockSwapFacade();
      when(() => swaps.watchOrder('order-1')).thenAnswer(
        (_) => Stream.value(
          const Err<OrderSwapRecord, SwapFailure>(
            SwapNetworkFailure(_rawReason),
          ),
        ),
      );

      final first = await WatchReceiveOrderSwapUsecase(
        swaps,
      ).execute('order-1').first;

      switch (first) {
        case Ok():
          fail('a swap failure must not be reported as an order update');
        case Err(:final failure):
          expect(failure, isA<ReceiveNetworkFailure>());
          // The upstream host stays in logMessage and never reaches the UI.
          expect(failure.logMessage, contains('10.0.0.7'));
      }
    },
  );

  test('maps a rate limit and carries retryAfter through, since the UI '
      'renders the wait', () async {
    final swaps = _MockSwapFacade();
    when(() => swaps.watchOrder('order-1')).thenAnswer(
      (_) => Stream.value(
        const Err<OrderSwapRecord, SwapFailure>(
          SwapRateLimitedFailure(
            retryAfter: Duration(seconds: 45),
            logMessage: _rawReason,
          ),
        ),
      ),
    );

    final first = await WatchReceiveOrderSwapUsecase(
      swaps,
    ).execute('order-1').first;

    switch (first) {
      case Ok():
        fail('a swap failure must not be reported as an order update');
      case Err(:final failure):
        expect(failure, isA<ReceiveRateLimitedFailure>());
        expect(
          (failure as ReceiveRateLimitedFailure).retryAfter,
          const Duration(seconds: 45),
        );
    }
  });

  test('maps an unknown swap failure to the catch-all, keeping the raw '
      'reason out of everything but logMessage', () async {
    final swaps = _MockSwapFacade();
    when(() => swaps.watchOrder('order-1')).thenAnswer(
      (_) => Stream.value(
        const Err<OrderSwapRecord, SwapFailure>(
          SwapUnexpectedFailure(_rawReason),
        ),
      ),
    );

    final first = await WatchReceiveOrderSwapUsecase(
      swaps,
    ).execute('order-1').first;

    switch (first) {
      case Ok():
        fail('a swap failure must not be reported as an order update');
      case Err(:final failure):
        expect(failure, isA<ReceiveUnexpectedFailure>());
        expect(failure.logMessage, contains('nginx'));
    }
  });
}
