import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';

/// Emits the user's virtual IBAN, `null` when there is none, and keeps
/// emitting until a pending one becomes active. With [createIfAbsent] it
/// creates a missing one first. A failure is the last event.
///
/// While the IBAN is pending it re-checks on the `VIRTUAL_IBAN_ACTIVATED`
/// notification (so activation is reflected as soon as the server pushes it),
/// and falls back to a poll in case the best-effort socket is unavailable.
class WatchVirtualIbanUsecase {
  final VirtualIbanRepository _virtualIbanRepository;
  final GetRecipientsEnvironmentUsecase _getRecipientsEnvironmentUsecase;
  final ExchangeNotificationRepository _exchangeNotificationRepository;
  final Duration _pollInterval;

  const WatchVirtualIbanUsecase({
    required this._virtualIbanRepository,
    required this._getRecipientsEnvironmentUsecase,
    required this._exchangeNotificationRepository,
    this._pollInterval = const Duration(seconds: 5),
  });

  static const _activatedEvent = 'VIRTUAL_IBAN_ACTIVATED';

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

    Completer<void>? pendingWake;
    final activation = _exchangeNotificationRepository.messages
        .where(
          (message) =>
              message.kind == NotificationMessageKind.recipient &&
              message.event == _activatedEvent,
        )
        .listen((_) {
          final wake = pendingWake;
          if (wake != null && !wake.isCompleted) wake.complete();
        });
    try {
      while (virtualIban is PendingVirtualIban) {
        final wake = Completer<void>();
        pendingWake = wake;
        await Future.any<void>([
          Future<void>.delayed(_pollInterval),
          wake.future,
        ]);
        switch (await _virtualIbanRepository.find(isTestnet: isTestnet)) {
          case Ok(value: final VirtualIban value):
            virtualIban = value;
            yield Ok(value);
          case Ok(value: null):
            yield const Err(
              RecipientsUnexpectedFailure(
                'The pending virtual IBAN disappeared',
              ),
            );
            return;
          case Err(:final failure):
            yield Err(failure);
            return;
        }
      }
    } finally {
      pendingWake = null;
      await activation.cancel();
    }
  }
}
