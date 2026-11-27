import 'package:exchange/exchange.dart' show WriteGateRefusal;
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

import 'autobuy_state.dart';
import 'autobuy_switch_effect.dart';
import 'autobuy_switch_event.dart';

/// The home card's AutoBuy switch. Turning it on opens the activation flow;
/// turning it off is a preference write verified by re-reading the account.
/// After a verified write the card shows what the re-read said, not the
/// summary it was built from (AB-3). Whether AutoBuy is on is a state
/// ([SwitchOff], [SwitchOn]): only an active AutoBuy can be deactivated, and
/// a deactivation (and the session ending during one) always starts from on.
/// [restricted] is the account's flag the card shows (the switch is not
/// offered while it is set); no transition depends on it.
@immutable
sealed class AutoBuySwitchState {
  const AutoBuySwitchState();

  AutoBuySwitchNext next(AutoBuySwitchEvent event) {
    final state = this;
    return switch ((state, event)) {
      (
        SwitchOff(:final restricted, :final problem) ||
            SwitchOn(:final restricted, :final problem),
        SwitchSummaryChanged(active: final now, restricted: final r),
      ) =>
        now == (state is SwitchOn) && r == restricted
            ? StepNext.stay(state)
            : StepNext(_shown(active: now, restricted: r, problem: problem)),
      (SwitchOn(:final restricted), SwitchDeactivatePressed()) => _confirmNext(
        restricted,
        serverConfirmStart<AutoBuyTarget, bool>(_off),
      ),
      (
        SwitchOff(),
        SwitchDeactivatePressed() ||
            SwitchRetryPressed() ||
            SwitchConfirmChanged(),
      ) =>
        StepNext.stay(state),
      (SwitchOn(), SwitchRetryPressed() || SwitchConfirmChanged()) =>
        StepNext.stay(state),
      (
        final SwitchDeactivating deactivating,
        SwitchConfirmChanged(:final event),
      ) =>
        _stepped(
          deactivating,
          deactivating.confirm.next(autoBuyWritePolicy, event),
        ),
      (final SwitchDeactivating deactivating, SwitchRetryPressed()) => _stepped(
        deactivating,
        deactivating.confirm.next(
          autoBuyWritePolicy,
          const ConfirmRetryPressed(),
        ),
      ),
      // A write is in flight or unverified: the summary may predate it.
      (
        SwitchDeactivating(),
        SwitchSummaryChanged() || SwitchDeactivatePressed(),
      ) =>
        StepNext.stay(state),
      (
        SwitchSessionEnded(),
        SwitchSummaryChanged() ||
            SwitchDeactivatePressed() ||
            SwitchRetryPressed() ||
            SwitchConfirmChanged(),
      ) =>
        StepNext.stay(state),
    };
  }
}

/// Why the last deactivation did not take effect, shown under the switch.
@immutable
sealed class AutoBuySwitchProblem {
  const AutoBuySwitchProblem();
}

final class SwitchWriteRefused extends AutoBuySwitchProblem {
  final WriteGateRefusal refusal;

  const SwitchWriteRefused(this.refusal);

  @override
  bool operator ==(Object other) =>
      other is SwitchWriteRefused && other.refusal == refusal;

  @override
  int get hashCode => Object.hash(SwitchWriteRefused, refusal);
}

final class SwitchWriteFailed extends AutoBuySwitchProblem {
  final WriteProblem problem;

  const SwitchWriteFailed(this.problem);

  @override
  bool operator ==(Object other) =>
      other is SwitchWriteFailed && other.problem == problem;

  @override
  int get hashCode => Object.hash(SwitchWriteFailed, problem);
}

/// AutoBuy is off; [problem] is why the last deactivation did not take
/// effect, when the summary turned it off since.
final class SwitchOff extends AutoBuySwitchState {
  final bool restricted;
  final AutoBuySwitchProblem? problem;

  const SwitchOff({required this.restricted, this.problem});

  @override
  bool operator ==(Object other) =>
      other is SwitchOff &&
      other.restricted == restricted &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(SwitchOff, restricted, problem);
}

/// AutoBuy is on; [problem] is why the last deactivation did not take
/// effect.
final class SwitchOn extends AutoBuySwitchState {
  final bool restricted;
  final AutoBuySwitchProblem? problem;

  const SwitchOn({required this.restricted, this.problem});

  @override
  bool operator ==(Object other) =>
      other is SwitchOn &&
      other.restricted == restricted &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(SwitchOn, restricted, problem);
}

/// Deactivating an active AutoBuy: [confirm] is Confirming, Verifying or
/// Unverified (Check again); the switch is not offered meanwhile.
final class SwitchDeactivating extends AutoBuySwitchState {
  final bool restricted;
  final AutoBuyConfirmState confirm;

  const SwitchDeactivating(this.restricted, this.confirm);

  @override
  bool operator ==(Object other) =>
      other is SwitchDeactivating &&
      other.restricted == restricted &&
      other.confirm == confirm;

  @override
  int get hashCode => Object.hash(SwitchDeactivating, restricted, confirm);
}

/// The session of the card ended during a deactivation (so AutoBuy was on).
/// Terminal; the dashboard rebuilds the card.
final class SwitchSessionEnded extends AutoBuySwitchState {
  const SwitchSessionEnded();

  @override
  bool operator ==(Object other) => other is SwitchSessionEnded;

  @override
  int get hashCode => (SwitchSessionEnded).hashCode;
}

typedef AutoBuySwitchNext = StepNext<AutoBuySwitchState, AutoBuySwitchEffect>;

const _off = AutoBuyTarget(enabled: false);

AutoBuySwitchNext autoBuySwitchStart({
  required bool active,
  required bool restricted,
}) => StepNext(_shown(active: active, restricted: restricted));

AutoBuySwitchState _shown({
  required bool active,
  required bool restricted,
  AutoBuySwitchProblem? problem,
}) => active
    ? SwitchOn(restricted: restricted, problem: problem)
    : SwitchOff(restricted: restricted, problem: problem);

/// The switch after the deactivation step moved to [next]; the deactivation
/// started from on.
AutoBuySwitchNext _confirmNext(
  bool restricted,
  ServerConfirmNext<AutoBuyTarget, bool> next,
) => switch (next.state) {
  ConfirmConfirmed(:final confirmed) => StepNext(
    _shown(active: confirmed, restricted: restricted),
    const [SwitchAccountChanged()],
  ),
  ConfirmSessionEnded() => StepNext(const SwitchSessionEnded()),
  ConfirmWriteRefused(:final refusal) => StepNext(
    SwitchOn(restricted: restricted, problem: SwitchWriteRefused(refusal)),
  ),
  // The re-read says the write did not apply, or it was refused / not
  // sent: nothing changed, the switch is offered again.
  ConfirmFailed(:final problem) => StepNext(
    SwitchOn(restricted: restricted, problem: SwitchWriteFailed(problem)),
    const [SwitchAccountChanged()],
  ),
  ConfirmLeft() => StepNext(SwitchOn(restricted: restricted)),
  ConfirmConfirming() || ConfirmVerifying() || ConfirmUnverified() => StepNext(
    SwitchDeactivating(restricted, next.state),
    [for (final effect in next.effects) SwitchConfirmEffect(effect)],
  ),
};

AutoBuySwitchNext _stepped(
  SwitchDeactivating state,
  ServerConfirmNext<AutoBuyTarget, bool> next,
) => identical(next.state, state.confirm) && next.effects.isEmpty
    ? StepNext.stay(state)
    : _confirmNext(state.restricted, next);
