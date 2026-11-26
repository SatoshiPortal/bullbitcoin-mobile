import 'package:swaps/swaps.dart' show AutoSwap, AutoswapFailure;
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

abstract interface class AutoswapProviderPort {
  @useResult
  Future<Result<String, AutoswapFailure>> execute(AutoSwap settings);
}
