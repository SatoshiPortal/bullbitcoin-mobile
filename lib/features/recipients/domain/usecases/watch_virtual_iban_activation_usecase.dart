import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/virtual_iban_status.dart';
import 'package:bull_logger/bull_logger.dart';

class WatchVirtualIbanActivationUsecase {
  final VirtualIbanRepository _repository;
  final SettingsRepository _settingsRepository;
  final Duration _pollInterval;

  WatchVirtualIbanActivationUsecase(
    this._repository,
    this._settingsRepository, [
    this._pollInterval = const Duration(seconds: 5),
  ]);

  Stream<Result<VirtualIbanStatus, RecipientsFailure>> execute({
    required bool createIfAbsent,
  }) async* {
    final bool isTestnet;
    try {
      final settings = await _settingsRepository.fetch();
      isTestnet = settings.environment.isTestnet;
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Could not prepare virtual IBAN activation',
        error: error,
        trace: stackTrace,
      );
      yield const Err(VirtualIbanFailure('Could not load settings'));
      return;
    }

    var result = await _repository.getStatus(isTestnet: isTestnet);
    if (result case Err(:final failure)) {
      yield Err(failure);
      return;
    }
    var status = (result as Ok<VirtualIbanStatus, RecipientsFailure>).value;
    if (status == VirtualIbanStatus.absent) {
      if (!createIfAbsent) {
        yield const Ok(VirtualIbanStatus.absent);
        return;
      }
      result = await _repository.create(isTestnet: isTestnet);
      if (result case Err(:final failure)) {
        yield Err(failure);
        return;
      }
      status = (result as Ok<VirtualIbanStatus, RecipientsFailure>).value;
    }

    yield Ok(status);
    while (status == VirtualIbanStatus.pending) {
      await Future<void>.delayed(_pollInterval);
      result = await _repository.getStatus(isTestnet: isTestnet);
      switch (result) {
        case Ok(:final value):
          status = value;
          yield Ok(status);
        case Err(:final failure):
          yield Err(failure);
          return;
      }
    }
  }
}
