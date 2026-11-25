import 'package:meta/meta.dart';

/// Something a payout rail needs before an order can pay a recipient
/// (composition §4.5). The requirements step meets each one with its own
/// machine, in the order the rail lists them.
@immutable
sealed class PayoutRequirement {
  const PayoutRequirement();
}

/// An Interac payout sends a security question and answer, prefilled from
/// the ones saved on the recipient.
final class InteracSecurityRequired extends PayoutRequirement {
  final String? question;
  final String? answer;

  const InteracSecurityRequired({this.question, this.answer});

  @override
  bool operator ==(Object other) =>
      other is InteracSecurityRequired &&
      other.question == question &&
      other.answer == answer;

  @override
  int get hashCode => Object.hash(InteracSecurityRequired, question, answer);

  @override
  String toString() => 'InteracSecurityRequired';
}

/// Confidential SEPA pays out from the user's own virtual IBAN, which must
/// be active.
final class VirtualIbanRequired extends PayoutRequirement {
  const VirtualIbanRequired();

  @override
  bool operator ==(Object other) => other is VirtualIbanRequired;

  @override
  int get hashCode => (VirtualIbanRequired).hashCode;

  @override
  String toString() => 'VirtualIbanRequired';
}

/// Confidential SEPA pays the recipient through its virtual payee, which
/// must be active. [alreadyActive] is what the recipient list said.
final class VirtualPayeeRequired extends PayoutRequirement {
  final bool alreadyActive;

  const VirtualPayeeRequired({required this.alreadyActive});

  @override
  bool operator ==(Object other) =>
      other is VirtualPayeeRequired && other.alreadyActive == alreadyActive;

  @override
  int get hashCode => Object.hash(VirtualPayeeRequired, alreadyActive);

  @override
  String toString() => 'VirtualPayeeRequired(alreadyActive: $alreadyActive)';
}
