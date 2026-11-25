import 'dart:async';

import 'package:bull_exchange/src/payout/domain/usecases/activate_virtual_payee_usecase.dart';
import 'package:bull_exchange/src/payout/domain/usecases/create_virtual_iban_usecase.dart';
import 'package:bull_exchange/src/payout/domain/usecases/find_virtual_iban_usecase.dart';
import 'package:bull_exchange/src/payout/domain/usecases/get_virtual_payee_status_usecase.dart';
import 'package:bull_exchange/src/payout/domain/usecases/load_virtual_iban_context_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

/// The use cases of the payout requirements step (composition §4.5). Only
/// [PayoutRequirementsRunner] calls them; a flow's bloc hands them over.
final class PayoutRequirementsUsecases {
  final LoadVirtualIbanContextUsecase loadVirtualIban;
  final CreateVirtualIbanUsecase createVirtualIban;
  final FindVirtualIbanUsecase findVirtualIban;
  final GetVirtualPayeeStatusUsecase payeeStatus;
  final ActivateVirtualPayeeUsecase activatePayee;

  const PayoutRequirementsUsecases({
    required this.loadVirtualIban,
    required this.createVirtualIban,
    required this.findVirtualIban,
    required this.payeeStatus,
    required this.activatePayee,
  });

  PayoutRequirementsUsecases.of(Exchange exchange)
    : this(
        loadVirtualIban: LoadVirtualIbanContextUsecase(exchange),
        createVirtualIban: CreateVirtualIbanUsecase(exchange),
        findVirtualIban: FindVirtualIbanUsecase(exchange),
        payeeStatus: GetVirtualPayeeStatusUsecase(exchange),
        activatePayee: ActivateVirtualPayeeUsecase(exchange),
      );
}

/// Runs the effects of the requirements step (virtual IBAN, virtual payee)
/// for a flow's bloc, with the flow's session, and answers with requirement
/// events. Poll and deadline timers live here, one per kind, so a
/// StopWatching or [close] ends them.
final class PayoutRequirementsRunner {
  final PayoutRequirementsUsecases _usecases;
  final ExchangeSession _session;
  final VirtualIbanPolicy _virtualIban;
  final void Function(RequirementsEvent event) _emit;

  Timer? _ibanPoll;
  Timer? _ibanDeadline;
  Timer? _payeePoll;
  Timer? _payeeDeadline;
  bool _closed = false;

  PayoutRequirementsRunner(
    this._usecases,
    this._session,
    this._emit, {
    this._virtualIban = const VirtualIbanPolicy(),
  });

  void run(List<RequirementsEffect> effects) {
    for (final effect in effects) {
      switch (effect) {
        case RequirementVirtualIbanEffect(:final effect):
          _iban(effect);
        case RequirementVirtualPayeeEffect(:final recipientId, :final effect):
          _payee(recipientId, effect);
      }
    }
  }

  void _iban(VirtualIbanEffect effect) {
    void answer(VirtualIbanEvent event) =>
        _send(RequirementVirtualIbanEvent(event));
    switch (effect) {
      case VibanLoad(:final attempt):
        unawaited(
          _usecases.loadVirtualIban
              .execute(_session)
              .then((r) => answer(VibanLoaded(attempt, r))),
        );
      case VibanCreate(:final attempt):
        unawaited(
          _usecases.createVirtualIban
              .execute(_session)
              .then((w) => answer(VibanCreated(attempt, w))),
        );
      case VibanVerify(:final attempt):
        unawaited(
          _usecases.findVirtualIban
              .execute(_session)
              .then((r) => answer(VibanVerified(attempt, r))),
        );
      case VibanSchedulePoll(:final ticket, :final immediate):
        _ibanPoll?.cancel();
        _ibanPoll = Timer(
          immediate ? Duration.zero : _virtualIban.pollEvery,
          () => unawaited(
            _usecases.findVirtualIban
                .execute(_session)
                .then((r) => answer(VibanPolled(ticket, r))),
          ),
        );
      case VibanCancelPoll():
        _ibanPoll?.cancel();
      case VibanStartDeadline(:final round, :final after):
        _ibanDeadline?.cancel();
        _ibanDeadline = Timer(after, () => answer(VibanDeadlinePassed(round)));
      case VibanStopWatching():
        _ibanPoll?.cancel();
        _ibanDeadline?.cancel();
    }
  }

  void _payee(String recipientId, VirtualPayeeEffect effect) {
    void answer(VirtualPayeeEvent event) =>
        _send(RequirementVirtualPayeeEvent(event));
    switch (effect) {
      case PayeeLoad(:final attempt):
        unawaited(
          _usecases.payeeStatus
              .execute(_session, recipientId)
              .then((r) => answer(PayeeLoaded(attempt, r))),
        );
      case PayeeActivate(:final attempt):
        unawaited(
          _usecases.activatePayee
              .execute(_session, recipientId)
              .then((w) => answer(PayeeActivated(attempt, w))),
        );
      case PayeeSchedulePoll(:final ticket, :final after):
        _payeePoll?.cancel();
        _payeePoll = Timer(
          after,
          () => unawaited(
            _usecases.payeeStatus
                .execute(_session, recipientId)
                .then((r) => answer(PayeePolled(ticket, r))),
          ),
        );
      case PayeeCancelPoll():
        _payeePoll?.cancel();
      case PayeeStartDeadline(:final round, :final after):
        _payeeDeadline?.cancel();
        _payeeDeadline = Timer(after, () => answer(PayeeDeadlinePassed(round)));
      case PayeeStopWatching():
        _payeePoll?.cancel();
        _payeeDeadline?.cancel();
    }
  }

  void _send(RequirementsEvent event) {
    if (!_closed) _emit(event);
  }

  void close() {
    _closed = true;
    for (final timer in [
      _ibanPoll,
      _ibanDeadline,
      _payeePoll,
      _payeeDeadline,
    ]) {
      timer?.cancel();
    }
  }
}
