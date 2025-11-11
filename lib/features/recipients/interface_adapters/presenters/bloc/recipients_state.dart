part of 'recipients_bloc.dart';

@freezed
sealed class RecipientsState with _$RecipientsState {
  const factory RecipientsState({
    @Default(false) bool isLoadingRecipients,
    Exception? failedToLoadRecipients,
    @Default(RecipientType.values) List<RecipientType> selectableRecipientTypes,
    List<RecipientViewModel>? recipients,
    @Default(false) bool isSearchingCadBillers,
    Exception? failedToSearchCadBillers,
    List<CadBillerViewModel>? cadBillers,
    @Default(false) bool isCheckingSinpe,
    Exception? failedToCheckSinpe,
    @Default('') String sinpeOwnerName,
    @Default(false) bool isAddingRecipient,
    Exception? failedToAddRecipient,
    @Default('') String selectedRecipientId,
  }) = _RecipientsState;
  const RecipientsState._();

  bool get isLoading =>
      isLoadingRecipients ||
      isAddingRecipient ||
      isCheckingSinpe ||
      isSearchingCadBillers;

  bool get hasSelectedRecipient => selectedRecipientId.isNotEmpty;

  Set<String> get availableJurisdictions =>
      selectableRecipientTypes.map((type) => type.jurisdictionCode).toSet();

  Set<RecipientType> recipientTypesForJurisdiction(String jurisdiction) {
    return selectableRecipientTypes
        .where((type) => type.jurisdictionCode == jurisdiction)
        .toSet();
  }

  List<RecipientViewModel>? filteredRecipientsByJurisdiction(
    String? jurisdiction,
  ) {
    if (jurisdiction == null) {
      return recipients;
    }

    return recipients
        ?.where((recipient) => recipient.jurisdictionCode == jurisdiction)
        .toList();
  }
}
