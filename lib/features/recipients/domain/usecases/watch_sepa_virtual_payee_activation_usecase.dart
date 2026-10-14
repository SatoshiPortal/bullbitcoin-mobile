import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';

/// Activates the virtual payee of a SEPA recipient when it has none, then
/// emits each new status until it is active. It checks often at first,
/// because activation usually takes a few seconds, then less often. A
/// failure is the last event.
class WatchSepaVirtualPayeeActivationUsecase {
  final SepaVirtualPayeeRepository _sepaVirtualPayeeRepository;
  final GetRecipientsEnvironmentUsecase _getRecipientsEnvironmentUsecase;
  final Duration _initialPollInterval;
  final int _initialPolls;
  final Duration _pollInterval;

  const WatchSepaVirtualPayeeActivationUsecase({
    required this._sepaVirtualPayeeRepository,
    required this._getRecipientsEnvironmentUsecase,
    this._initialPollInterval = const Duration(seconds: 1),
    this._initialPolls = 8,
    this._pollInterval = const Duration(seconds: 5),
  });

  Stream<Result<SepaVirtualPayeeStatus, RecipientsFailure>> execute({
    required String recipientId,
  }) async* {
    final bool isTestnet;
    switch (await _getRecipientsEnvironmentUsecase.execute()) {
      case Ok(:final value):
        isTestnet = value.isTestnet;
      case Err(:final failure):
        yield Err(failure);
        return;
    }

    final initialStatus = await _findStatus(recipientId, isTestnet);
    SepaVirtualPayeeStatus status;
    switch (initialStatus) {
      case Ok(:final value):
        status = value;
      case Err(:final failure):
        yield Err(failure);
        return;
    }

    if (!status.exists) {
      switch (await _sepaVirtualPayeeRepository.activate(
        recipientId: recipientId,
        isTestnet: isTestnet,
      )) {
        case Ok(:final value):
          status = value;
        case Err(:final failure):
          yield Err(failure);
          return;
      }
    }

    yield Ok(status);
    var polls = 0;
    while (!status.isActive) {
      await Future<void>.delayed(
        polls < _initialPolls ? _initialPollInterval : _pollInterval,
      );
      polls++;
      switch (await _findStatus(recipientId, isTestnet)) {
        case Ok(:final value):
          if (value != status) yield Ok(value);
          status = value;
        case Err(:final failure):
          yield Err(failure);
          return;
      }
    }
  }

  Future<Result<SepaVirtualPayeeStatus, RecipientsFailure>> _findStatus(
    String recipientId,
    bool isTestnet,
  ) async {
    final result = await _sepaVirtualPayeeRepository.findStatus(
      recipientId: recipientId,
      isTestnet: isTestnet,
    );
    return switch (result) {
      Ok(value: final SepaVirtualPayeeStatus status) => Ok(status),
      Ok(value: null) => const Err(
        RecipientsUnexpectedFailure('The SEPA recipient was not found'),
      ),
      Err(:final failure) => Err(failure),
    };
  }
}
