import 'package:bull_exchange/src/recipients/public/recipient_view_model.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart' show listsEqual;
import 'package:meta/meta.dart';

/// What the recipients machine asks its bloc to run; each answers with the
/// matching `Recipients*Answered` event.
@immutable
sealed class RecipientsEffect {
  const RecipientsEffect();
}

final class RecipientsReadSepaAvailability extends RecipientsEffect {
  const RecipientsReadSepaAvailability();

  @override
  bool operator ==(Object other) => other is RecipientsReadSepaAvailability;

  @override
  int get hashCode => (RecipientsReadSepaAvailability).hashCode;
}

/// Read only once Confidential SEPA is known not to be unavailable.
final class RecipientsReadOwnerName extends RecipientsEffect {
  const RecipientsReadOwnerName();

  @override
  bool operator ==(Object other) => other is RecipientsReadOwnerName;

  @override
  int get hashCode => (RecipientsReadOwnerName).hashCode;
}

final class RecipientsReadPreferredJurisdiction extends RecipientsEffect {
  const RecipientsReadPreferredJurisdiction();

  @override
  bool operator ==(Object other) =>
      other is RecipientsReadPreferredJurisdiction;

  @override
  int get hashCode => (RecipientsReadPreferredJurisdiction).hashCode;
}

/// Read [page] of the list for load [generation].
final class RecipientsFetchPage extends RecipientsEffect {
  final int generation;
  final int page;
  final List<RecipientType> types;
  final bool? isOwner;
  final String search;

  const RecipientsFetchPage({
    required this.generation,
    required this.page,
    required this.types,
    required this.isOwner,
    required this.search,
  });

  @override
  bool operator ==(Object other) =>
      other is RecipientsFetchPage &&
      other.generation == generation &&
      other.page == page &&
      listsEqual(other.types, types) &&
      other.isOwner == isOwner &&
      other.search == search;

  @override
  int get hashCode => Object.hash(
    RecipientsFetchPage,
    generation,
    page,
    Object.hashAll(types),
    isOwner,
    search,
  );
}

/// Wait out the typing pause of search [ticket] before it is applied.
final class RecipientsSearchPause extends RecipientsEffect {
  final int ticket;
  final String query;

  const RecipientsSearchPause(this.ticket, this.query);

  @override
  bool operator ==(Object other) =>
      other is RecipientsSearchPause &&
      other.ticket == ticket &&
      other.query == query;

  @override
  int get hashCode => Object.hash(RecipientsSearchPause, ticket, query);
}

final class RecipientsSave extends RecipientsEffect {
  final RecipientDetailsInput recipient;

  const RecipientsSave(this.recipient);

  @override
  bool operator ==(Object other) =>
      other is RecipientsSave && other.recipient == recipient;

  @override
  int get hashCode => Object.hash(RecipientsSave, recipient);
}

/// Hand [recipient] to the caller's selection hook.
final class RecipientsRunSelection extends RecipientsEffect {
  final RecipientViewModel recipient;
  final bool isNew;

  const RecipientsRunSelection(this.recipient, {required this.isNew});

  @override
  bool operator ==(Object other) =>
      other is RecipientsRunSelection &&
      other.recipient == recipient &&
      other.isNew == isNew;

  @override
  int get hashCode => Object.hash(RecipientsRunSelection, recipient, isNew);
}

final class RecipientsCheckSinpe extends RecipientsEffect {
  final String phoneNumber;

  const RecipientsCheckSinpe(this.phoneNumber);

  @override
  bool operator ==(Object other) =>
      other is RecipientsCheckSinpe && other.phoneNumber == phoneNumber;

  @override
  int get hashCode => Object.hash(RecipientsCheckSinpe, phoneNumber);
}

final class RecipientsSearchBillers extends RecipientsEffect {
  final String query;

  const RecipientsSearchBillers(this.query);

  @override
  bool operator ==(Object other) =>
      other is RecipientsSearchBillers && other.query == query;

  @override
  int get hashCode => Object.hash(RecipientsSearchBillers, query);
}
