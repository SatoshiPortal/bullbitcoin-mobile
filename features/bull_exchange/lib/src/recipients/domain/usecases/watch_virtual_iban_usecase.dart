import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_recipients_environment_usecase.dart';
import 'package:exchange/exchange.dart';

import '../map_virtual_iban_failure.dart';

/// Emits the user's virtual IBAN, `null` when there is none, and keeps
/// emitting until a pending one becomes active. With [createIfAbsent] it
/// creates a missing one first. A failure is the last event.
///
/// While the IBAN is pending it re-checks on the `VIRTUAL_IBAN_ACTIVATED`
/// notification (so activation is reflected as soon as the server pushes it),
/// and falls back to a poll in case the best-effort socket is unavailable.
class WatchVirtualIbanUsecase {
  final VirtualIbansRepository _virtualIbans;
  final GetRecipientsEnvironmentUsecase _getRecipientsEnvironmentUsecase;
  final Stream<Result<NotificationMessage, ExchangeFailure>> _notifications;
  final Duration _pollInterval;

  const WatchVirtualIbanUsecase({
    required this._virtualIbans,
    required this._getRecipientsEnvironmentUsecase,
    required this._notifications,
    this._pollInterval = const Duration(seconds: 5),
  });

  static const _activatedEvent = 'VIRTUAL_IBAN_ACTIVATED';

  Stream<Result<VirtualIban?, RecipientsFailure>> execute({
    required bool createIfAbsent,
  }) async* {
    final ExchangeEnvironment environment;
    switch (await _getRecipientsEnvironmentUsecase.execute()) {
      case Ok(:final value):
        environment = value.requireHistoricalTestnet()
            ? ExchangeEnvironment.testnet
            : ExchangeEnvironment.mainnet;
      case Err(:final failure):
        yield Err(failure);
        return;
    }

    VirtualIban? virtualIban;
    switch (await _virtualIbans.find(environment)) {
      case Ok(:final value):
        virtualIban = value;
      case Err(:final failure):
        yield Err(mapVirtualIbanFailure(failure));
        return;
    }

    if (virtualIban == null && createIfAbsent) {
      switch (await _virtualIbans.create(environment)) {
        case Ok(:final value):
          virtualIban = value;
        case Err(:final failure):
          yield Err(mapVirtualIbanFailure(failure));
          return;
      }
    }

    yield Ok(virtualIban);

    Completer<void>? pendingWake;
    final activation = _notifications
        .where(
          (event) =>
              event is Ok<NotificationMessage, ExchangeFailure> &&
              event.value.kind == NotificationMessageKind.recipient &&
              event.value.event == _activatedEvent,
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
        switch (await _virtualIbans.find(environment)) {
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
            yield Err(mapVirtualIbanFailure(failure));
            return;
        }
      }
    } finally {
      pendingWake = null;
      await activation.cancel();
    }
  }
}
