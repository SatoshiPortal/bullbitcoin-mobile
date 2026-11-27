import 'package:meta/meta.dart';

import 'consent_gate_event.dart';

@immutable
sealed class ConsentGateEffect {
  const ConsentGateEffect();
}

/// Send the consent; answer [ConsentSubmitted] for [attempt].
final class ConsentSubmit extends ConsentGateEffect {
  final int attempt;

  const ConsentSubmit(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ConsentSubmit && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ConsentSubmit, attempt);
}

/// Read whether consent is on the account; answer [ConsentVerified].
final class ConsentVerify extends ConsentGateEffect {
  final int attempt;

  const ConsentVerify(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ConsentVerify && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ConsentVerify, attempt);
}
