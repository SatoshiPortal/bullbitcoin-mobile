import 'package:swap_feature/swap_feature.dart';

class RetrySwapsOnRefreshUsecase {
  final SwapActivity _swaps;

  const RetrySwapsOnRefreshUsecase(this._swaps);

  Future<void> execute() => _swaps.retryOngoingSwaps();
}
