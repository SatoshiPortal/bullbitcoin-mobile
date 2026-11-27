import 'package:meta/meta.dart';

import '../domain/entities/virtual_iban.dart';
import '../payout/order_payout_params.dart';
import '../payout/payout_rail.dart';
import '../payout/payout_requirement.dart';
import '../payout/recipient_choice.dart';
import 'interac_security_event.dart';
import 'interac_security_state.dart';
import 'requirements_effect.dart';
import 'requirements_event.dart';
import 'step_next.dart';
import 'virtual_iban_state.dart';
import 'virtual_iban_event.dart';
import 'virtual_iban_effect.dart';
import 'virtual_payee_state.dart';
import 'virtual_payee_event.dart';
import 'virtual_payee_effect.dart';

/// Proof that one requirement of a rail is met. Only the requirement steps
/// make the values it holds.
@immutable
sealed class RequirementEvidence {
  const RequirementEvidence();
}

final class InteracSecurityMet extends RequirementEvidence {
  final InteracSecurityEvidence evidence;

  const InteracSecurityMet(this.evidence);

  @override
  bool operator ==(Object other) =>
      other is InteracSecurityMet && other.evidence == evidence;

  @override
  int get hashCode => Object.hash(InteracSecurityMet, evidence);
}

final class VirtualIbanMet extends RequirementEvidence {
  final ActiveVirtualIban virtualIban;

  const VirtualIbanMet(this.virtualIban);

  @override
  bool operator ==(Object other) =>
      other is VirtualIbanMet && other.virtualIban == virtualIban;

  @override
  int get hashCode => Object.hash(VirtualIbanMet, virtualIban);
}

final class VirtualPayeeMet extends RequirementEvidence {
  const VirtualPayeeMet();

  @override
  bool operator ==(Object other) => other is VirtualPayeeMet;

  @override
  int get hashCode => (VirtualPayeeMet).hashCode;
}

/// The output of the requirements step (composition §4.5): a chosen
/// recipient with every requirement of its rail met. Only the step makes
/// one, so an order can't be created for a recipient whose virtual payee
/// isn't active or whose Interac answer is missing: [orderParams] needs it.
@immutable
final class ReadyRecipient {
  final ChosenRecipient chosen;
  final List<RequirementEvidence> evidence;

  const ReadyRecipient._(this.chosen, this.evidence);

  PayoutRail get rail => chosen.rail;

  /// The Interac answer the order sends, when the rail asked for one.
  InteracSecurityEvidence? get interac {
    for (final met in evidence) {
      if (met case InteracSecurityMet(:final evidence)) return evidence;
    }
    return null;
  }

  /// What the order sends about the payout.
  OrderPayoutParams get orderParams => rail.orderParams(this);

  @override
  bool operator ==(Object other) {
    if (other is! ReadyRecipient ||
        other.chosen != chosen ||
        other.evidence.length != evidence.length) {
      return false;
    }
    for (var i = 0; i < evidence.length; i++) {
      if (other.evidence[i] != evidence[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(chosen, Object.hashAll(evidence));

  @override
  String toString() => 'ReadyRecipient($chosen, ${evidence.length} met)';
}

@immutable
final class RequirementsPolicy {
  final VirtualIbanPolicy virtualIban;
  final VirtualPayeePolicy virtualPayee;

  const RequirementsPolicy({
    this.virtualIban = const VirtualIbanPolicy(),
    this.virtualPayee = const VirtualPayeePolicy(),
  });
}

/// The machine of the requirement being met.
@immutable
sealed class RequirementStep {
  const RequirementStep();
}

final class InteracStep extends RequirementStep {
  final InteracSecurityState state;

  const InteracStep(this.state);

  @override
  bool operator ==(Object other) =>
      other is InteracStep && other.state == state;

  @override
  int get hashCode => Object.hash(InteracStep, state);

  @override
  String toString() => 'InteracStep($state)';
}

final class VirtualIbanStep extends RequirementStep {
  final VirtualIbanState state;

  const VirtualIbanStep(this.state);

  @override
  bool operator ==(Object other) =>
      other is VirtualIbanStep && other.state == state;

  @override
  int get hashCode => Object.hash(VirtualIbanStep, state);

  @override
  String toString() => 'VirtualIbanStep($state)';
}

final class VirtualPayeeStep extends RequirementStep {
  final VirtualPayeeState state;

  const VirtualPayeeStep(this.state);

  @override
  bool operator ==(Object other) =>
      other is VirtualPayeeStep && other.state == state;

  @override
  int get hashCode => Object.hash(VirtualPayeeStep, state);

  @override
  String toString() => 'VirtualPayeeStep($state)';
}

/// The requirements step (composition §4.5): runs the rail's requirements
/// in order. A recipient whose requirements are already met passes straight
/// to [RequirementsReady].
@immutable
sealed class RequirementsState {
  const RequirementsState();

  /// Events for a requirement that is not the current one are stays.
  RequirementsNext next(RequirementsPolicy policy, RequirementsEvent event) {
    final state = this;
    return switch ((state, event)) {
      (
        final RequirementsRunning running,
        RequirementInteracEvent(:final event),
      ) =>
        _onInterac(policy, running, event),
      (
        final RequirementsRunning running,
        RequirementVirtualIbanEvent(:final event),
      ) =>
        _onVirtualIban(policy, running, event),
      (
        final RequirementsRunning running,
        RequirementVirtualPayeeEvent(:final event),
      ) =>
        _onVirtualPayee(policy, running, event),
      (final RequirementsRunning running, RequirementsCancelPressed()) =>
        StepNext(const RequirementsCancelled(), _stopEffects(running)),

      (
        RequirementsReady() ||
            RequirementsCancelled() ||
            RequirementsSessionEnded(),
        RequirementInteracEvent() ||
            RequirementVirtualIbanEvent() ||
            RequirementVirtualPayeeEvent() ||
            RequirementsCancelPressed(),
      ) =>
        StepNext.stay(state),
    };
  }
}

final class RequirementsRunning extends RequirementsState {
  final ChosenRecipient chosen;
  final PayoutPurpose purpose;

  /// The requirements after [current], in order.
  final List<PayoutRequirement> queue;

  /// The evidence of the requirements met so far.
  final List<RequirementEvidence> met;

  final RequirementStep current;

  const RequirementsRunning({
    required this.chosen,
    required this.purpose,
    required this.queue,
    required this.met,
    required this.current,
  });

  @override
  bool operator ==(Object other) =>
      other is RequirementsRunning &&
      other.chosen == chosen &&
      other.purpose == purpose &&
      _sameList(other.queue, queue) &&
      _sameList(other.met, met) &&
      other.current == current;

  @override
  int get hashCode => Object.hash(
    chosen,
    purpose,
    Object.hashAll(queue),
    Object.hashAll(met),
    current,
  );

  @override
  String toString() => 'RequirementsRunning($chosen, $current)';
}

/// Output.
final class RequirementsReady extends RequirementsState {
  final ReadyRecipient ready;

  const RequirementsReady(this.ready);

  @override
  bool operator ==(Object other) =>
      other is RequirementsReady && other.ready == ready;

  @override
  int get hashCode => Object.hash(RequirementsReady, ready);

  @override
  String toString() => 'RequirementsReady($ready)';
}

/// The user left, or declined a requirement whose rail has no fallback:
/// the flow goes back to picking a recipient. Terminal.
final class RequirementsCancelled extends RequirementsState {
  const RequirementsCancelled();
}

/// A call got HTTP 401. Terminal; the flow ends its session.
final class RequirementsSessionEnded extends RequirementsState {
  const RequirementsSessionEnded();
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

typedef RequirementsNext = StepNext<RequirementsState, RequirementsEffect>;

RequirementsNext requirementsStart(
  RequirementsPolicy policy,
  ChosenRecipient chosen,
  PayoutPurpose purpose,
) => _advance(policy, chosen, purpose, chosen.requirements(purpose), const []);

/// Starts the next requirement of [queue], or ends Ready when none is left.
/// A requirement that is met at its start (a payee the list shows active)
/// is passed without a screen.
RequirementsNext _advance(
  RequirementsPolicy policy,
  ChosenRecipient chosen,
  PayoutPurpose purpose,
  List<PayoutRequirement> queue,
  List<RequirementEvidence> met,
) {
  if (queue.isEmpty) {
    return StepNext(RequirementsReady(ReadyRecipient._(chosen, met)));
  }
  final rest = queue.sublist(1);
  final (step, effects) = switch (queue.first) {
    final InteracSecurityRequired requirement => (
      InteracStep(interacSecurityStart(requirement).state),
      const <RequirementsEffect>[],
    ),
    VirtualIbanRequired() => _iban(virtualIbanStart()),
    final VirtualPayeeRequired requirement => _payee(
      chosen,
      virtualPayeeStart(requirement),
    ),
  };
  return _settle(
    policy,
    RequirementsRunning(
      chosen: chosen,
      purpose: purpose,
      queue: rest,
      met: met,
      current: step,
    ),
    effects,
  );
}

(RequirementStep, List<RequirementsEffect>) _iban(VirtualIbanNext next) => (
  VirtualIbanStep(next.state),
  [for (final effect in next.effects) RequirementVirtualIbanEffect(effect)],
);

(RequirementStep, List<RequirementsEffect>) _payee(
  ChosenRecipient chosen,
  VirtualPayeeNext next,
) => (
  VirtualPayeeStep(next.state),
  [
    for (final effect in next.effects)
      RequirementVirtualPayeeEffect(chosen.recipient.recipientId, effect),
  ],
);

/// What a running step whose current machine just moved becomes: the next
/// requirement when it is met, the fallback rail when it was declined, the
/// end of the session, or the step with the machine's new state.
RequirementsNext _settle(
  RequirementsPolicy policy,
  RequirementsRunning running,
  List<RequirementsEffect> effects,
) {
  final met = switch (running.current) {
    InteracStep(state: InteracAnswered(:final evidence)) => InteracSecurityMet(
      evidence,
    ),
    VirtualIbanStep(state: VibanActive(:final virtualIban)) => VirtualIbanMet(
      virtualIban,
    ),
    VirtualPayeeStep(state: PayeeActive()) => const VirtualPayeeMet(),
    InteracStep() || VirtualIbanStep() || VirtualPayeeStep() => null,
  };
  if (met != null) {
    final next = _advance(
      policy,
      running.chosen,
      running.purpose,
      running.queue,
      [...running.met, met],
    );
    return StepNext(next.state, [...effects, ...next.effects]);
  }
  final declined = switch (running.current) {
    VirtualIbanStep(state: VibanDeclined()) ||
    VirtualPayeeStep(state: PayeeDeclined()) => true,
    InteracStep() || VirtualIbanStep() || VirtualPayeeStep() => false,
  };
  if (declined) {
    final fallback = running.chosen.fallback;
    if (fallback == null) {
      return StepNext(const RequirementsCancelled(), effects);
    }
    final next = _advance(
      policy,
      fallback,
      running.purpose,
      fallback.requirements(running.purpose),
      const [],
    );
    return StepNext(next.state, [...effects, ...next.effects]);
  }
  final ended = switch (running.current) {
    VirtualIbanStep(state: VibanSessionEnded()) ||
    VirtualPayeeStep(state: PayeeSessionEnded()) => true,
    InteracStep() || VirtualIbanStep() || VirtualPayeeStep() => false,
  };
  if (ended) return StepNext(const RequirementsSessionEnded(), effects);
  return StepNext(running, effects);
}

RequirementsRunning _with(RequirementsRunning running, RequirementStep step) =>
    RequirementsRunning(
      chosen: running.chosen,
      purpose: running.purpose,
      queue: running.queue,
      met: running.met,
      current: step,
    );

RequirementsNext _onInterac(
  RequirementsPolicy policy,
  RequirementsRunning running,
  InteracSecurityEvent event,
) {
  if (running.current case InteracStep(state: final current)) {
    final next = current.next(event);
    if (identical(next.state, current)) return StepNext.stay(running);
    return _settle(policy, _with(running, InteracStep(next.state)), const []);
  }
  return StepNext.stay(running);
}

RequirementsNext _onVirtualIban(
  RequirementsPolicy policy,
  RequirementsRunning running,
  VirtualIbanEvent event,
) {
  if (running.current case VirtualIbanStep(state: final current)) {
    final next = current.next(policy.virtualIban, event);
    if (identical(next.state, current)) return StepNext.stay(running);
    final (step, effects) = _iban(next);
    return _settle(policy, _with(running, step), effects);
  }
  return StepNext.stay(running);
}

RequirementsNext _onVirtualPayee(
  RequirementsPolicy policy,
  RequirementsRunning running,
  VirtualPayeeEvent event,
) {
  if (running.current case VirtualPayeeStep(state: final current)) {
    final next = current.next(policy.virtualPayee, event);
    if (identical(next.state, current)) return StepNext.stay(running);
    final (step, effects) = _payee(running.chosen, next);
    return _settle(policy, _with(running, step), effects);
  }
  return StepNext.stay(running);
}

/// Leaving while a requirement polls stops its watch.
List<RequirementsEffect> _stopEffects(RequirementsRunning running) =>
    switch (running.current) {
      VirtualIbanStep(state: VibanActivating() || VibanPaused()) => const [
        RequirementVirtualIbanEffect(VibanStopWatching()),
      ],
      VirtualPayeeStep(state: PayeePending() || PayeePaused()) => [
        RequirementVirtualPayeeEffect(
          running.chosen.recipient.recipientId,
          const PayeeStopWatching(),
        ),
      ],
      InteracStep() || VirtualIbanStep() || VirtualPayeeStep() => const [],
    };
