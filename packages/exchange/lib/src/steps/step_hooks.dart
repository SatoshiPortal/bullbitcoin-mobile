import '../recipients/domain/entities/recipient.dart';

/// Output of the recipient pick step (composition §4.4), built in C3 on the
/// payout rails: a recipient picked under the flow's filter. Flows that
/// pay out to a recipient take it into their order request.
abstract interface class ChosenRecipient {
  Recipient get recipient;
}

/// Output of the requirements step (composition §4.5), built in C3: a
/// chosen recipient with every requirement of its rail met (Interac
/// security details, an active virtual IBAN or payee). The order request
/// reads its evidence through the rail.
abstract interface class ReadyRecipient {
  ChosenRecipient get chosen;
}
