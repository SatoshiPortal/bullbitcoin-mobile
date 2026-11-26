import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'entities/virtual_iban.dart';
import 'exchange_environment.dart';
import 'exchange_failure.dart';

abstract interface class ExchangeVirtualIbans {
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

final class ExchangeVirtualIbansImpl implements ExchangeVirtualIbans {
  final Future<Result<VirtualIban?, ExchangeFailure>> Function(
    ExchangeEnvironment,
  )
  _find;
  final Future<Result<VirtualIban, ExchangeFailure>> Function(
    ExchangeEnvironment,
  )
  _create;

  const ExchangeVirtualIbansImpl({required this._find, required this._create});

  @override
  Future<Result<VirtualIban?, ExchangeFailure>> find(
    ExchangeEnvironment environment,
  ) => _find(environment);

  @override
  Future<Result<VirtualIban, ExchangeFailure>> create(
    ExchangeEnvironment environment,
  ) => _create(environment);
}
