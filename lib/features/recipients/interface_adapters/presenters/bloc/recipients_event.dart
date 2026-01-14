part of 'recipients_bloc.dart';

@freezed
sealed class RecipientsEvent with _$RecipientsEvent {
  const factory RecipientsEvent.started({
    /// When true, skips Step 1 (type selection) and goes directly to Step 2.
    @Default(false) bool skipTypeSelection,
  }) = RecipientsStarted;
  const factory RecipientsEvent.moreLoaded() = RecipientsMoreLoaded;
  const factory RecipientsEvent.added(RecipientFormDataModel recipient) =
      RecipientsAdded;
  const factory RecipientsEvent.sinpeChecked(String phoneNumber) =
      RecipientsSinpeChecked;
  const factory RecipientsEvent.cadBillersSearched(String query) =
      RecipientsCadBillersSearched;
  const factory RecipientsEvent.selected(RecipientViewModel recipient) =
      RecipientsSelected;

  // Virtual IBAN step flow navigation events
  const factory RecipientsEvent.nextStepPressed({
    required RecipientType selectedType,
  }) = RecipientsNextStepPressed;
  const factory RecipientsEvent.previousStepPressed() =
      RecipientsPreviousStepPressed;
  const factory RecipientsEvent.virtualIbanActivated() =
      RecipientsVirtualIbanActivated;
  const factory RecipientsEvent.fallbackToRegularSepa() =
      RecipientsFallbackToRegularSepa;

  // Virtual IBAN default type selection event
  const factory RecipientsEvent.defaultTypeSelected({
    required RecipientType type,
  }) = RecipientsDefaultTypeSelected;
}
