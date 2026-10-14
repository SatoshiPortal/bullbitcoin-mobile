import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';

/// Emits the user's virtual IBAN, `null` when there is none, and keeps
/// emitting until a pending one becomes active. With [createIfAbsent] it
/// creates a missing one first. A failure is the last event.
class WatchVirtualIbanUsecase {
  final VirtualIbanRepository _virtualIbanRepository;
  final GetRecipientsEnvironmentUsecase _getRecipientsEnvironmentUsecase;
  final Duration _pollInterval;

  const WatchVirtualIbanUsecase({
    required this._virtualIbanRepository,
    required this._getRecipientsEnvironmentUsecase,
    this._pollInterval = const Duration(seconds: 5),
  });

  Stream<Result<VirtualIban?, RecipientsFailure>> execute({
    required bool createIfAbsent,
  }) async* {
    final bool isTestnet;
    switch (await _getRecipientsEnvironmentUsecase.execute()) {
      case Ok(:final value):
        isTestnet = value.isTestnet;
      case Err(:final failure):
        yield Err(failure);
        return;
    }

    VirtualIban? virtualIban;
    switch (await _virtualIbanRepository.find(isTestnet: isTestnet)) {
      case Ok(:final value):
        virtualIban = value;
      case Err(:final failure):
        yield Err(failure);
        return;
    }

    if (virtualIban == null && createIfAbsent) {
      switch (await _virtualIbanRepository.create(isTestnet: isTestnet)) {
        case Ok(:final value):
          virtualIban = value;
        case Err(:final failure):
          yield Err(failure);
          return;
      }
    }

    yield Ok(virtualIban);
    while (virtualIban is PendingVirtualIban) {
      await Future<void>.delayed(_pollInterval);
      switch (await _virtualIbanRepository.find(isTestnet: isTestnet)) {
        case Ok(value: final VirtualIban value):
          virtualIban = value;
          yield Ok(value);
        case Ok(value: null):
          yield const Err(
            RecipientsUnexpectedFailure('The pending virtual IBAN disappeared'),
          );
          return;
        case Err(:final failure):
          yield Err(failure);
          return;
      }
    }
  }
}
