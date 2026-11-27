part of 'recipients_bloc.dart';

@freezed
sealed class RecipientsEvent with _$RecipientsEvent {
  const factory RecipientsEvent.started() = RecipientsStarted;
  const factory RecipientsEvent.moreLoaded() = RecipientsMoreLoaded;
  const factory RecipientsEvent.refreshed() = RecipientsRefreshed;
  const factory RecipientsEvent.confidentialSepaAvailabilityRetried() =
      RecipientsConfidentialSepaAvailabilityRetried;
  const factory RecipientsEvent.jurisdictionChanged(String? jurisdiction) =
      RecipientsJurisdictionChanged;
  const factory RecipientsEvent.searchChanged(String query) =
      RecipientsSearchChanged;
  const factory RecipientsEvent.added(RecipientFormDataModel recipient) =
      RecipientsAdded;

  /// The user picked another jurisdiction or recipient type on the
  /// new-recipient tab, so the last save error is about a form that is gone.
  const factory RecipientsEvent.newRecipientFormChanged() =
      RecipientsNewRecipientFormChanged;
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
}
