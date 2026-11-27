import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/virtual_iban.dart';
import '../exchange_environment.dart';
import '../exchange_failure.dart';

abstract interface class VirtualIbansRepository {
  /// A successful null means there is no virtual IBAN yet.
  @useResult
  Future<Result<VirtualIban?, ExchangeFailure>> find(
    ExchangeEnvironment environment,
  );
  @useResult
  Future<Result<VirtualIban, ExchangeFailure>> create(
    ExchangeEnvironment environment,
  );
}
