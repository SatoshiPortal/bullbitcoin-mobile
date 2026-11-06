import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';

abstract interface class AutoSwapSettingsRepository {
  Future<AutoSwap> getAutoSwapParams();

  Future<void> updateAutoSwapParams(AutoSwap params);

  Stream<AutoSwap> watchAutoSwapParams();
}

/// The legacy throwing repository refuses before reading or changing a
/// historical network's settings. Feature use cases map it to AutoswapFailure.
final class AutoswapNetworkUnavailableException implements Exception {
  const AutoswapNetworkUnavailableException();
}
