import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange_access/data/exchange_access_repository_impl.dart';
import 'package:bb_mobile/features/exchange_access/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange_access/domain/exchange_access_failure.dart';
import 'package:bb_mobile/features/exchange_access/domain/repositories/exchange_access_repository.dart';
import 'package:bb_mobile/features/exchange_access/domain/usecases/exchange_access_controller.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/core/utils/result.dart' show Err, Ok, Result;
export '../exchange_access_locator.dart' show ExchangeAccessLocator;
export '../domain/exchange_access.dart';
export '../domain/exchange_access_failure.dart';
export '../domain/repositories/exchange_access_repository.dart';

class ExchangeAccessFacade {
  ExchangeAccessFacade({ExchangeAccessRepository? repository})
    : _controller = ExchangeAccessController(
        repository: repository ?? ExchangeAccessRepositoryImpl(),
      );

  final ExchangeAccessController _controller;
  ExchangeAccess get current => _controller.current;
  int get generation => _controller.generation;
  void suspend() => _controller.suspend();
  Future<void> settle() => _controller.settle();
  bool? get isTestnet => _controller.isTestnet;
  Stream<ExchangeAccess> watch() => _controller.watch();
  @useResult
  Future<Result<ExchangeAccessOutcome, ExchangeAccessFailure>> initialize({
    required bool isTestnet,
    required ExchangeSessionFact session,
  }) => _controller.initialize(isTestnet: isTestnet, session: session);
  @useResult
  Future<Result<ExchangeAccessOutcome, ExchangeAccessFailure>> reconcileSession(
    ExchangeSessionFact session, {
    int? generation,
  }) => _controller.reconcileSession(session, generation: generation);
  @useResult
  Future<Result<ExchangeAccessOutcome, ExchangeAccessFailure>> choose(
    bool enabled,
  ) => _controller.choose(enabled);
  @useResult
  Future<Result<ExchangeAccessOutcome, ExchangeAccessFailure>>
  beginActivation() => _controller.beginActivation();
  @useResult
  Future<Result<ExchangeAccessOutcome, ExchangeAccessFailure>>
  cancelActivation({int? generation}) =>
      _controller.cancelActivation(generation: generation);
  @useResult
  Future<Result<ExchangeAccessOutcome, ExchangeAccessFailure>> disable(
    Future<bool> Function() cleanup,
  ) => _controller.disable(cleanup);
  Future<void> dispose() => _controller.dispose();
}
