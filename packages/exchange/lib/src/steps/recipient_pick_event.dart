import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_failure.dart';
import '../domain/exchange_page.dart';
import '../payout/payout_rail.dart';
import '../recipients/domain/entities/recipient.dart';
import '../recipients/domain/entities/recipient_details_input.dart';
import 'recipient_pick_state.dart';

@immutable
sealed class RecipientPickEvent {
  const RecipientPickEvent();
}

final class RecipientPickPageLoaded extends RecipientPickEvent {
  final int attempt;
  final Result<ExchangePage<Recipient>, ExchangeListFailure> page;

  const RecipientPickPageLoaded(this.attempt, this.page);
}

final class RecipientPickQueryChanged extends RecipientPickEvent {
  final RecipientQuery query;

  const RecipientPickQueryChanged(this.query);
}

final class RecipientPickMoreRequested extends RecipientPickEvent {
  const RecipientPickMoreRequested();
}

final class RecipientPickRetryPressed extends RecipientPickEvent {
  const RecipientPickRetryPressed();
}

final class RecipientPickSelected extends RecipientPickEvent {
  final Recipient recipient;

  const RecipientPickSelected(this.recipient);
}

final class RecipientPickNewPressed extends RecipientPickEvent {
  final PayoutRail rail;

  const RecipientPickNewPressed(this.rail);
}

/// The form of the current rail was submitted with [input].
final class RecipientPickSubmitted extends RecipientPickEvent {
  final RecipientDetailsInput input;

  const RecipientPickSubmitted(this.input);
}

final class RecipientPickSaved extends RecipientPickEvent {
  final int attempt;
  final Result<Recipient, ExchangeWriteFailure> write;

  const RecipientPickSaved(this.attempt, this.write);
}

/// The re-read after an unknown save: [Ok] the recipient with the same
/// account, [ExchangeMissingFailure] when there is none.
final class RecipientPickFound extends RecipientPickEvent {
  final int attempt;
  final Result<Recipient, ExchangeReadFailure> read;

  const RecipientPickFound(this.attempt, this.read);
}

final class RecipientPickBackPressed extends RecipientPickEvent {
  const RecipientPickBackPressed();
}
