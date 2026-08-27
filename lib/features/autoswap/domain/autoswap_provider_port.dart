import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:meta/meta.dart';

abstract interface class AutoswapProviderPort {
  @useResult
  Future<Result<String, AutoswapFailure>> execute(AutoSwap settings);
}
