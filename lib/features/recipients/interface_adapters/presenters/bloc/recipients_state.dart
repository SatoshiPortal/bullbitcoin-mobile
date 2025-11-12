part of 'recipients_bloc.dart';

@freezed
sealed class RecipientsState with _$RecipientsState {
  const factory RecipientsState({
    @Default(false) bool isLoadingRecipients,
    Exception? failedToLoadRecipients,
    required AllowedRecipientFiltersViewModel allowedRecipientFilters,
    List<RecipientViewModel>? recipients,
    @Default(false) bool isSearchingCadBillers,
    Exception? failedToSearchCadBillers,
    List<CadBillerViewModel>? cadBillers,
    @Default(false) bool isCheckingSinpe,
    Exception? failedToCheckSinpe,
    @Default('') String sinpeOwnerName,
    @Default(false) bool isAddingRecipient,
    Exception? failedToAddRecipient,
    RecipientViewModel? selectedRecipient,
  }) = _RecipientsState;
  const RecipientsState._();

  bool get isLoading =>
      isLoadingRecipients ||
      isAddingRecipient ||
      isCheckingSinpe ||
      isSearchingCadBillers;

  bool get hasSelectedRecipient => selectedRecipient != null;

  Set<RecipientType> get selectableRecipientTypes =>
      allowedRecipientFilters.types.toSet();

  bool get onlyOwnerRecipients => allowedRecipientFilters.isOwner ?? false;

  bool get onlyNonOwnerRecipients => allowedRecipientFilters.isOwner == false;

  Set<String> get availableJurisdictions =>
      selectableRecipientTypes.map((type) => type.jurisdictionCode).toSet();

  Set<RecipientType> recipientTypesForJurisdiction(String jurisdiction) {
    return selectableRecipientTypes
        .where((type) => type.jurisdictionCode == jurisdiction)
        .toSet();
  }

  List<RecipientViewModel>? get selectableRecipients {
    // Apply filters to the full recipient list based on the allowed recipient types
    // and ownership criteria.
    return recipients
        ?.where(
          (recipient) =>
              selectableRecipientTypes.any((type) => type == recipient.type) &&
              !(onlyOwnerRecipients && !(recipient.isOwner == true) ||
                  onlyNonOwnerRecipients && !(recipient.isOwner == false)),
        )
        .toList();
  }

  List<RecipientViewModel>? filteredRecipientsByJurisdiction(
    String? jurisdiction,
  ) {
    if (jurisdiction == null) {
      return selectableRecipients;
    }

    return selectableRecipients
        ?.where((recipient) => recipient.jurisdictionCode == jurisdiction)
        .toList();
  }
}
