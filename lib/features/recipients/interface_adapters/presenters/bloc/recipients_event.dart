part of 'recipients_bloc.dart';

@freezed
sealed class RecipientsEvent with _$RecipientsEvent {
  const factory RecipientsEvent.loadRecipients({
    Set<RecipientType>? selectableRecipientTypes,
  }) = LoadRecipientsEvent;
  const factory RecipientsEvent.addRecipient() = AddRecipientEvent;
  const factory RecipientsEvent.checkSinpe(String phoneNumber) =
      CheckSinpeEvent;
  const factory RecipientsEvent.searchCadBillers(String query) =
      SearchCadBillersEvent;
}
