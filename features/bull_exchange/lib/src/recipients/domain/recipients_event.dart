import 'package:bull_exchange/src/recipients/domain/entities/account_owner_name.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/add_recipient_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/check_sinpe_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_recipients_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/list_cad_billers_usecase.dart';
import 'package:bull_exchange/src/recipients/public/recipient_view_model.dart';
import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// What the recipients screen asks for, and what the reads and writes it
/// started answered.
@immutable
sealed class RecipientsEvent {
  const RecipientsEvent();

  const factory RecipientsEvent.started() = RecipientsStarted;
  const factory RecipientsEvent.moreLoaded() = RecipientsMoreLoaded;
  const factory RecipientsEvent.refreshed() = RecipientsRefreshed;
  const factory RecipientsEvent.confidentialSepaAvailabilityRetried() =
      RecipientsConfidentialSepaAvailabilityRetried;
  const factory RecipientsEvent.jurisdictionChanged(
    Jurisdiction? jurisdiction,
  ) = RecipientsJurisdictionChanged;
  const factory RecipientsEvent.searchChanged(String query) =
      RecipientsSearchChanged;
  const factory RecipientsEvent.added(RecipientDetailsInput recipient) =
      RecipientsAdded;
  const factory RecipientsEvent.sinpeChecked(String phoneNumber) =
      RecipientsSinpeChecked;
  const factory RecipientsEvent.cadBillersSearched(String query) =
      RecipientsCadBillersSearched;
  const factory RecipientsEvent.selected(RecipientViewModel recipient) =
      RecipientsSelected;
  const factory RecipientsEvent.virtualIbanActivated() =
      RecipientsVirtualIbanActivated;
  const factory RecipientsEvent.sepaTypeChanged(RecipientType sepaType) =
      RecipientsSepaTypeChanged;

  /// The new-recipient form now shows another country or payout method:
  /// the last save's failure was about the form that is gone.
  const factory RecipientsEvent.newRecipientFormChanged() =
      RecipientsNewRecipientFormChanged;
}

final class RecipientsStarted extends RecipientsEvent {
  const RecipientsStarted();

  @override
  bool operator ==(Object other) => other is RecipientsStarted;

  @override
  int get hashCode => (RecipientsStarted).hashCode;
}

final class RecipientsMoreLoaded extends RecipientsEvent {
  const RecipientsMoreLoaded();

  @override
  bool operator ==(Object other) => other is RecipientsMoreLoaded;

  @override
  int get hashCode => (RecipientsMoreLoaded).hashCode;
}

final class RecipientsRefreshed extends RecipientsEvent {
  const RecipientsRefreshed();

  @override
  bool operator ==(Object other) => other is RecipientsRefreshed;

  @override
  int get hashCode => (RecipientsRefreshed).hashCode;
}

final class RecipientsConfidentialSepaAvailabilityRetried
    extends RecipientsEvent {
  const RecipientsConfidentialSepaAvailabilityRetried();

  @override
  bool operator ==(Object other) =>
      other is RecipientsConfidentialSepaAvailabilityRetried;

  @override
  int get hashCode => (RecipientsConfidentialSepaAvailabilityRetried).hashCode;
}

final class RecipientsJurisdictionChanged extends RecipientsEvent {
  final Jurisdiction? jurisdiction;

  const RecipientsJurisdictionChanged(this.jurisdiction);

  @override
  bool operator ==(Object other) =>
      other is RecipientsJurisdictionChanged &&
      other.jurisdiction == jurisdiction;

  @override
  int get hashCode => Object.hash(RecipientsJurisdictionChanged, jurisdiction);
}

final class RecipientsSearchChanged extends RecipientsEvent {
  final String query;

  const RecipientsSearchChanged(this.query);

  @override
  bool operator ==(Object other) =>
      other is RecipientsSearchChanged && other.query == query;

  @override
  int get hashCode => Object.hash(RecipientsSearchChanged, query);
}

final class RecipientsAdded extends RecipientsEvent {
  final RecipientDetailsInput recipient;

  const RecipientsAdded(this.recipient);

  @override
  bool operator ==(Object other) =>
      other is RecipientsAdded && other.recipient == recipient;

  @override
  int get hashCode => Object.hash(RecipientsAdded, recipient);
}

final class RecipientsSinpeChecked extends RecipientsEvent {
  final String phoneNumber;

  const RecipientsSinpeChecked(this.phoneNumber);

  @override
  bool operator ==(Object other) =>
      other is RecipientsSinpeChecked && other.phoneNumber == phoneNumber;

  @override
  int get hashCode => Object.hash(RecipientsSinpeChecked, phoneNumber);
}

final class RecipientsCadBillersSearched extends RecipientsEvent {
  final String query;

  const RecipientsCadBillersSearched(this.query);

  @override
  bool operator ==(Object other) =>
      other is RecipientsCadBillersSearched && other.query == query;

  @override
  int get hashCode => Object.hash(RecipientsCadBillersSearched, query);
}

final class RecipientsSelected extends RecipientsEvent {
  final RecipientViewModel recipient;

  const RecipientsSelected(this.recipient);

  @override
  bool operator ==(Object other) =>
      other is RecipientsSelected && other.recipient == recipient;

  @override
  int get hashCode => Object.hash(RecipientsSelected, recipient);
}

final class RecipientsVirtualIbanActivated extends RecipientsEvent {
  const RecipientsVirtualIbanActivated();

  @override
  bool operator ==(Object other) => other is RecipientsVirtualIbanActivated;

  @override
  int get hashCode => (RecipientsVirtualIbanActivated).hashCode;
}

final class RecipientsSepaTypeChanged extends RecipientsEvent {
  final RecipientType sepaType;

  const RecipientsSepaTypeChanged(this.sepaType);

  @override
  bool operator ==(Object other) =>
      other is RecipientsSepaTypeChanged && other.sepaType == sepaType;

  @override
  int get hashCode => Object.hash(RecipientsSepaTypeChanged, sepaType);
}

final class RecipientsNewRecipientFormChanged extends RecipientsEvent {
  const RecipientsNewRecipientFormChanged();

  @override
  bool operator ==(Object other) => other is RecipientsNewRecipientFormChanged;

  @override
  int get hashCode => (RecipientsNewRecipientFormChanged).hashCode;
}

/// The search [query] typed as search [ticket] waited out its pause.
final class RecipientsSearchSettled extends RecipientsEvent {
  final int ticket;
  final String query;

  const RecipientsSearchSettled(this.ticket, this.query);

  @override
  bool operator ==(Object other) =>
      other is RecipientsSearchSettled &&
      other.ticket == ticket &&
      other.query == query;

  @override
  int get hashCode => Object.hash(RecipientsSearchSettled, ticket, query);
}

/// The page read of load [generation] answered.
final class RecipientsPageAnswered extends RecipientsEvent {
  final int generation;
  final Result<GetRecipientsResult, ExchangeFailure> page;

  const RecipientsPageAnswered(this.generation, this.page);

  @override
  bool operator ==(Object other) =>
      other is RecipientsPageAnswered &&
      other.generation == generation &&
      other.page == page;

  @override
  int get hashCode => Object.hash(RecipientsPageAnswered, generation, page);
}

final class RecipientsSepaAvailabilityAnswered extends RecipientsEvent {
  final Result<ConfidentialSepaAvailability, ExchangeFailure> availability;

  const RecipientsSepaAvailabilityAnswered(this.availability);

  @override
  bool operator ==(Object other) =>
      other is RecipientsSepaAvailabilityAnswered &&
      other.availability == availability;

  @override
  int get hashCode =>
      Object.hash(RecipientsSepaAvailabilityAnswered, availability);
}

final class RecipientsOwnerNameAnswered extends RecipientsEvent {
  final Result<AccountOwnerName, ExchangeFailure> ownerName;

  const RecipientsOwnerNameAnswered(this.ownerName);

  @override
  bool operator ==(Object other) =>
      other is RecipientsOwnerNameAnswered && other.ownerName == ownerName;

  @override
  int get hashCode => Object.hash(RecipientsOwnerNameAnswered, ownerName);
}

final class RecipientsPreferenceAnswered extends RecipientsEvent {
  final Result<Jurisdiction?, ExchangeFailure> jurisdiction;

  const RecipientsPreferenceAnswered(this.jurisdiction);

  @override
  bool operator ==(Object other) =>
      other is RecipientsPreferenceAnswered &&
      other.jurisdiction == jurisdiction;

  @override
  int get hashCode => Object.hash(RecipientsPreferenceAnswered, jurisdiction);
}

final class RecipientsSaveAnswered extends RecipientsEvent {
  final Result<AddRecipientResult, ExchangeFailure> saved;

  const RecipientsSaveAnswered(this.saved);

  @override
  bool operator ==(Object other) =>
      other is RecipientsSaveAnswered && other.saved == saved;

  @override
  int get hashCode => Object.hash(RecipientsSaveAnswered, saved);
}

/// The caller's selection hook ran for the recipient just saved.
final class RecipientsSavedSelectionAnswered extends RecipientsEvent {
  final Result<void, ExchangeRecipientsSelectionFailure> selected;

  const RecipientsSavedSelectionAnswered(this.selected);

  @override
  bool operator ==(Object other) =>
      other is RecipientsSavedSelectionAnswered && other.selected == selected;

  @override
  int get hashCode => Object.hash(RecipientsSavedSelectionAnswered, selected);
}

/// The caller's selection hook ran for a recipient picked from the list.
final class RecipientsSelectionAnswered extends RecipientsEvent {
  final Result<void, ExchangeRecipientsSelectionFailure> selected;

  const RecipientsSelectionAnswered(this.selected);

  @override
  bool operator ==(Object other) =>
      other is RecipientsSelectionAnswered && other.selected == selected;

  @override
  int get hashCode => Object.hash(RecipientsSelectionAnswered, selected);
}

final class RecipientsSinpeAnswered extends RecipientsEvent {
  final Result<CheckSinpeResult, ExchangeFailure> owner;

  const RecipientsSinpeAnswered(this.owner);

  @override
  bool operator ==(Object other) =>
      other is RecipientsSinpeAnswered && other.owner == owner;

  @override
  int get hashCode => Object.hash(RecipientsSinpeAnswered, owner);
}

final class RecipientsBillersAnswered extends RecipientsEvent {
  final Result<ListCadBillersResult, ExchangeFailure> billers;

  const RecipientsBillersAnswered(this.billers);

  @override
  bool operator ==(Object other) =>
      other is RecipientsBillersAnswered && other.billers == billers;

  @override
  int get hashCode => Object.hash(RecipientsBillersAnswered, billers);
}
