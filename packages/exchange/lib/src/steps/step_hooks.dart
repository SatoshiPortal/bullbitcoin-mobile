import '../payout/recipient_choice.dart';

/// Output of the requirements step (composition §4.5), built in C3: a
/// chosen recipient with every requirement of its rail met (Interac
/// security details, an active virtual IBAN or payee). The order request
/// reads its evidence through the rail.
abstract interface class ReadyRecipient {
  ChosenRecipient get chosen;
}
