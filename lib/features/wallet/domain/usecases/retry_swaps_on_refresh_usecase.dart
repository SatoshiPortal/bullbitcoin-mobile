import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class RetrySwapsOnRefreshUsecase {
  final SwapFacade _swaps;

  const RetrySwapsOnRefreshUsecase(this._swaps);

  Future<void> execute() => _swaps.retryOngoingSwaps();
}
