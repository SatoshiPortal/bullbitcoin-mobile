import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_activation_progress.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';
import 'package:bull_logger/bull_logger.dart';

class WatchSepaVirtualPayeeActivationUsecase {
  final SepaVirtualPayeeRepository _repository;
  final SettingsRepository _settingsRepository;
  final Duration _initialPollInterval;
  final Duration _pollInterval;
  final int _initialWaitPolls;

  WatchSepaVirtualPayeeActivationUsecase(
    this._repository,
    this._settingsRepository, [
    this._initialPollInterval = const Duration(seconds: 1),
    this._pollInterval = const Duration(seconds: 5),
    this._initialWaitPolls = 8,
  ]);

  Stream<Result<SepaVirtualPayeeActivationProgress, RecipientsFailure>>
  execute({required String recipientId}) async* {
    final bool isTestnet;
    try {
      final settings = await _settingsRepository.fetch();
      isTestnet = settings.environment.isTestnet;
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Could not prepare virtual payee refresh',
        error: error,
        trace: stackTrace,
      );
      yield const Err(
        RecipientRefreshFailure('Could not prepare virtual payee refresh'),
      );
      return;
    }

    final initial = await _repository.find(
      recipientId: recipientId,
      isTestnet: isTestnet,
    );
    Recipient? recipient;
    switch (initial) {
      case Ok(:final value):
        recipient = value;
      case Err(:final failure):
        yield Err(failure);
        return;
    }

    if (recipient?.details case final SepaEurDetails details
        when details.isVirtualPayeeActive) {
      yield Ok(_progress(_asConfidential(recipient!), false));
      return;
    }

    if (_hasUnknownStatus(recipient)) {
      yield const Err(RecipientRefreshFailure('Unknown virtual payee status'));
      return;
    }

    final shouldActivate = switch (recipient?.details) {
      final SepaEurDetails details => !details.hasVirtualPayee,
      _ => true,
    };
    if (shouldActivate) {
      final activation = await _repository.activate(
        recipientId: recipientId,
        isTestnet: isTestnet,
      );
      switch (activation) {
        case Ok(:final value):
          recipient = _asConfidential(value);
          yield Ok(_progress(recipient, false));
          if ((recipient.details as SepaEurDetails).isVirtualPayeeActive) {
            return;
          }
        case Err(:final failure):
          yield Err(failure);
          return;
      }
    }

    var pollCount = 0;
    while (true) {
      await Future<void>.delayed(
        pollCount < _initialWaitPolls ? _initialPollInterval : _pollInterval,
      );
      final refreshed = await _repository.find(
        recipientId: recipientId,
        isTestnet: isTestnet,
      );
      switch (refreshed) {
        case Ok(value: final value?):
          recipient = _asConfidential(value);
          if (_hasUnknownStatus(recipient)) {
            yield const Err(
              RecipientRefreshFailure('Unknown virtual payee status'),
            );
            return;
          }
          pollCount++;
          yield Ok(_progress(recipient, pollCount >= _initialWaitPolls));
          if ((recipient.details as SepaEurDetails).isVirtualPayeeActive) {
            return;
          }
        case Ok(value: null):
          pollCount++;
          if (recipient != null) {
            yield Ok(_progress(recipient, pollCount >= _initialWaitPolls));
          }
        case Err(:final failure):
          yield Err(failure);
          return;
      }
    }
  }

  bool _hasUnknownStatus(Recipient? recipient) {
    final details = recipient?.details;
    return details is SepaEurDetails &&
        details.virtualPayeeStatus == SepaVirtualPayeeStatus.unknown;
  }

  SepaVirtualPayeeActivationProgress _progress(
    Recipient recipient,
    bool initialWaitTimedOut,
  ) => SepaVirtualPayeeActivationProgress(
    recipient: recipient,
    initialWaitTimedOut: initialWaitTimedOut,
  );

  Recipient _asConfidential(Recipient recipient) {
    final details = recipient.details;
    if (details is! SepaEurDetails) return recipient;
    return Recipient.create(
      recipientId: recipient.recipientId,
      userId: recipient.userId,
      userNbr: recipient.userNbr,
      isArchived: recipient.isArchived,
      createdAt: recipient.createdAt,
      updatedAt: recipient.updatedAt,
      details: details.asConfidential(),
    );
  }
}
