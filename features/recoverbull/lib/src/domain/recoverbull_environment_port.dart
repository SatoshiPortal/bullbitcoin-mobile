import 'package:primitives/primitives.dart';
import 'recoverbull_failure.dart';

abstract interface class RecoverBullEnvironmentPort {
  Future<Result<BitcoinNetwork, RecoverBullFailure>> currentNetwork();
}
