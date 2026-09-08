import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';

abstract interface class AutoSwapSettingsRepository {
  Future<AutoSwap> getAutoSwapParams();

  Future<void> updateAutoSwapParams(AutoSwap params);

  Stream<AutoSwap> watchAutoSwapParams();
}
