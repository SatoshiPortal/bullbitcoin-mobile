import 'dart:async';

import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

/// The exchange calls the payout requirements (composition §4.5) need, bound
/// to one session.
typedef PayoutRequirementsCalls = ({
  Future<ExchangeRead<VirtualIbanContext>> Function() loadVirtualIban,
  Future<ExchangeWrite<VirtualIban>> Function() createVirtualIban,
  Future<ExchangeRead<VirtualIban?>> Function() findVirtualIban,
  Future<ExchangeRead<SepaVirtualPayeeStatus>> Function(String recipientId)
  payeeStatus,
  Future<ExchangeWrite<SepaVirtualPayeeStatus>> Function(String recipientId)
  activatePayee,
});

PayoutRequirementsCalls payoutRequirementsCallsOf(
  Exchange exchange,
  ExchangeSession session,
) {
  final environment = session.environment;
  final isTestnet = environment == ExchangeEnvironment.testnet;
  Future<ExchangeRead<VirtualIban?>> find() async =>
      readOfResult(await exchange.virtualIbans.find(environment));
  Future<ExchangeRead<SepaVirtualPayeeStatus>> status(String id) async =>
      switch (await exchange.recipients.findStatus(
        recipientId: id,
        isTestnet: isTestnet,
      )) {
        Ok(value: final SepaVirtualPayeeStatus status) => ReadGot(status),
        Ok(value: null) => const ReadMissing(),
        Err(:final failure) => readOfExchangeFailure(failure),
      };
  return (
    loadVirtualIban: () async {
      final owner = readOfResult(await exchange.getUserSummary(environment));
      final iban = await find();
      return switch ((owner, iban)) {
        (ReadGot(value: final summary), ReadGot(value: final virtualIban)) =>
          ReadGot(
            VirtualIbanContext(
              virtualIban: virtualIban,
              ownerName:
                  '${summary.profile.firstName.trim()} '
                          '${summary.profile.lastName.trim()}'
                      .trim(),
            ),
          ),
        (ReadSessionRejected(:final why), _) ||
        (_, ReadSessionRejected(:final why)) => ReadSessionRejected(why),
        (ReadGot(), final failed) => _failedRead(failed),
        (final failed, _) => _failedRead(failed),
      };
    },
    createVirtualIban: () async =>
        writeOfResult(await exchange.virtualIbans.create(environment)),
    findVirtualIban: find,
    payeeStatus: status,
    activatePayee: (id) async => writeOfResult(
      await exchange.recipients.activate(recipientId: id, isTestnet: isTestnet),
    ),
  );
}

ExchangeRead<T> _failedRead<T>(ExchangeRead<Object?> read) => switch (read) {
  ReadMissing() => const ReadMissing(),
  ReadUnreachable(:final reason, :final isNetwork) => ReadUnreachable(
    reason,
    isNetwork: isNetwork,
  ),
  ReadMalformed(:final reason) => ReadMalformed(reason),
  ReadSessionRejected(:final why) => ReadSessionRejected(why),
  ReadGot() => const ReadMalformed('combined read'),
};

/// Runs the effects of the requirements step (virtual IBAN, virtual payee)
/// for a flow's bloc and answers with requirement events. Poll and deadline
/// timers live here, one per kind, so a StopWatching or [close] ends them.
final class PayoutRequirementsRunner {
  final PayoutRequirementsCalls _calls;
  final VirtualIbanPolicy _virtualIban;
  final void Function(RequirementsEvent event) _emit;

  Timer? _ibanPoll;
  Timer? _ibanDeadline;
  Timer? _payeePoll;
  Timer? _payeeDeadline;
  bool _closed = false;

  PayoutRequirementsRunner(
    this._calls,
    this._emit, {
    VirtualIbanPolicy virtualIban = const VirtualIbanPolicy(),
  }) : _virtualIban = virtualIban;

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
          _calls.loadVirtualIban().then((r) => answer(VibanLoaded(attempt, r))),
        );
      case VibanCreate(:final attempt):
        unawaited(
          _calls.createVirtualIban().then(
            (w) => answer(VibanCreated(attempt, w)),
          ),
        );
      case VibanVerify(:final attempt):
        unawaited(
          _calls.findVirtualIban().then(
            (r) => answer(VibanVerified(attempt, r)),
          ),
        );
      case VibanSchedulePoll(:final ticket, :final immediate):
        _ibanPoll?.cancel();
        _ibanPoll = Timer(
          immediate ? Duration.zero : _virtualIban.pollEvery,
          () => unawaited(
            _calls.findVirtualIban().then(
              (r) => answer(VibanPolled(ticket, r)),
            ),
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
          _calls
              .payeeStatus(recipientId)
              .then((r) => answer(PayeeLoaded(attempt, r))),
        );
      case PayeeActivate(:final attempt):
        unawaited(
          _calls
              .activatePayee(recipientId)
              .then((w) => answer(PayeeActivated(attempt, w))),
        );
      case PayeeSchedulePoll(:final ticket, :final after):
        _payeePoll?.cancel();
        _payeePoll = Timer(
          after,
          () => unawaited(
            _calls
                .payeeStatus(recipientId)
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
