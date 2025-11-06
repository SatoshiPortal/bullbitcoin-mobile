part of 'recipients_bloc.dart';

@freezed
sealed class RecipientsEvent with _$RecipientsEvent {
  const factory RecipientsEvent.loaded({
    Set<RecipientType>? selectableRecipientTypes,
  }) = RecipientsLoaded;
  const factory RecipientsEvent.added(RecipientFormDataModel recipient) =
      RecipientsAdded;
  const factory RecipientsEvent.sinpeChecked(String phoneNumber) =
      RecipientsSinpeChecked;
  const factory RecipientsEvent.cadBillersSearched(String query) =
      RecipientsCadBillersSearched;
}
