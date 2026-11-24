import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

import 'autobuy_flow.dart';

/// The home card's AutoBuy switch. Turning it on opens the activation flow;
/// turning it off is a preference write verified by re-reading the account.
/// After a verified write the card shows what the re-read said, not the
/// summary it was built from (AB-3).
@immutable
sealed class AutoBuySwitchState {
  const AutoBuySwitchState();

  bool get active;
  bool get restricted;
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

final class SwitchShown extends AutoBuySwitchState {
  @override
  final bool active;
  @override
  final bool restricted;
  final AutoBuySwitchProblem? problem;

  const SwitchShown({
    required this.active,
    required this.restricted,
    this.problem,
  });

  @override
  bool operator ==(Object other) =>
      other is SwitchShown &&
      other.active == active &&
      other.restricted == restricted &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(SwitchShown, active, restricted, problem);
}

/// Deactivating: [confirm] is Confirming, Verifying or Unverified (Check
/// again); the switch is not offered meanwhile.
final class SwitchDeactivating extends AutoBuySwitchState {
  @override
  final bool active;
  @override
  final bool restricted;
  final AutoBuyConfirmState confirm;

  const SwitchDeactivating(this.active, this.restricted, this.confirm);

  @override
  bool operator ==(Object other) =>
      other is SwitchDeactivating &&
      other.active == active &&
      other.restricted == restricted &&
      other.confirm == confirm;

  @override
  int get hashCode =>
      Object.hash(SwitchDeactivating, active, restricted, confirm);
}

/// The session of the card ended. Terminal; the dashboard rebuilds the card.
final class SwitchSessionEnded extends AutoBuySwitchState {
  @override
  final bool active;
  @override
  final bool restricted;

  const SwitchSessionEnded(this.active, this.restricted);

  @override
  bool operator ==(Object other) =>
      other is SwitchSessionEnded &&
      other.active == active &&
      other.restricted == restricted;

  @override
  int get hashCode => Object.hash(SwitchSessionEnded, active, restricted);
}

@immutable
sealed class AutoBuySwitchEvent {
  const AutoBuySwitchEvent();
}

/// The dashboard's summary changed (a refresh, the activation flow).
final class SwitchSummaryChanged extends AutoBuySwitchEvent {
  final bool active;
  final bool restricted;

  const SwitchSummaryChanged({required this.active, required this.restricted});
}

/// The user confirmed the deactivate dialog.
final class SwitchDeactivatePressed extends AutoBuySwitchEvent {
  const SwitchDeactivatePressed();
}

final class SwitchRetryPressed extends AutoBuySwitchEvent {
  const SwitchRetryPressed();
}

final class SwitchConfirmChanged extends AutoBuySwitchEvent {
  final AutoBuyConfirmEvent event;

  const SwitchConfirmChanged(this.event);
}

@immutable
sealed class AutoBuySwitchEffect {
  const AutoBuySwitchEffect();
}

final class SwitchConfirmEffect extends AutoBuySwitchEffect {
  final ServerConfirmEffect<AutoBuyTarget> effect;

  const SwitchConfirmEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is SwitchConfirmEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(SwitchConfirmEffect, effect);
}

/// Tell the dashboard the account changed, so it reads it again.
final class SwitchAccountChanged extends AutoBuySwitchEffect {
  const SwitchAccountChanged();

  @override
  bool operator ==(Object other) => other is SwitchAccountChanged;

  @override
  int get hashCode => (SwitchAccountChanged).hashCode;
}

typedef AutoBuySwitchNext = StepNext<AutoBuySwitchState, AutoBuySwitchEffect>;

const _off = AutoBuyTarget(enabled: false);

AutoBuySwitchNext autoBuySwitchStart({
  required bool active,
  required bool restricted,
}) => StepNext(SwitchShown(active: active, restricted: restricted));

AutoBuySwitchNext _confirmNext(
  AutoBuySwitchState state,
  ServerConfirmNext<AutoBuyTarget, bool> next,
) => switch (next.state) {
  ConfirmConfirmed(:final confirmed) => StepNext(
    SwitchShown(active: confirmed, restricted: state.restricted),
    const [SwitchAccountChanged()],
  ),
  ConfirmSessionEnded() => StepNext(
    SwitchSessionEnded(state.active, state.restricted),
  ),
  ConfirmWriteRefused(:final refusal) => StepNext(
    SwitchShown(
      active: state.active,
      restricted: state.restricted,
      problem: SwitchWriteRefused(refusal),
    ),
  ),
  // The re-read says the write did not apply, or it was refused / not
  // sent: nothing changed, the switch is offered again.
  ConfirmFailed(:final problem) => StepNext(
    SwitchShown(
      active: state.active,
      restricted: state.restricted,
      problem: SwitchWriteFailed(problem),
    ),
    const [SwitchAccountChanged()],
  ),
  ConfirmLeft() => StepNext(
    SwitchShown(active: state.active, restricted: state.restricted),
  ),
  ConfirmConfirming() || ConfirmVerifying() || ConfirmUnverified() => StepNext(
    SwitchDeactivating(state.active, state.restricted, next.state),
    [for (final effect in next.effects) SwitchConfirmEffect(effect)],
  ),
};

AutoBuySwitchNext transitionAutoBuySwitch(
  AutoBuySwitchState state,
  AutoBuySwitchEvent event,
) => switch ((state, event)) {
  (
    SwitchShown(:final active, :final restricted, :final problem),
    SwitchSummaryChanged(active: final now, restricted: final r),
  ) =>
    now == active && r == restricted
        ? StepNext.stay(state)
        : StepNext(SwitchShown(active: now, restricted: r, problem: problem)),
  (SwitchShown(:final active), SwitchDeactivatePressed()) when active =>
    _confirmNext(state, serverConfirmStart<AutoBuyTarget, bool>(_off)),
  (
    SwitchShown(),
    SwitchDeactivatePressed() || SwitchRetryPressed() || SwitchConfirmChanged(),
  ) =>
    StepNext.stay(state),
  (SwitchDeactivating(:final confirm), SwitchConfirmChanged(:final event)) =>
    _stepped(
      state,
      transitionServerConfirm(autoBuyWritePolicy, confirm, event),
    ),
  (SwitchDeactivating(:final confirm), SwitchRetryPressed()) => _stepped(
    state,
    transitionServerConfirm(
      autoBuyWritePolicy,
      confirm,
      const ConfirmRetryPressed(),
    ),
  ),
  // A write is in flight or unverified: the summary may predate it.
  (SwitchDeactivating(), SwitchSummaryChanged() || SwitchDeactivatePressed()) =>
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

AutoBuySwitchNext _stepped(
  SwitchDeactivating state,
  ServerConfirmNext<AutoBuyTarget, bool> next,
) => identical(next.state, state.confirm) && next.effects.isEmpty
    ? StepNext.stay(state)
    : _confirmNext(state, next);
