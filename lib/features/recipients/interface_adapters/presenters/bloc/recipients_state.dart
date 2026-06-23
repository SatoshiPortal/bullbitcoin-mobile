part of 'recipients_bloc.dart';

@freezed
sealed class RecipientsState with _$RecipientsState {
  const factory RecipientsState({
    String? preferredJurisdiction,
    String? jurisdictionFilter,
    @Default('') String searchQuery,
    @Default(false) bool isLoadingRecipients,
    Exception? failedToLoadRecipients,
    required RecipientFilterCriteria allowedRecipientFilters,
    List<RecipientViewModel>? recipients,
    int? totalRecipients,
    @Default(false) bool isSearchingCadBillers,
    Exception? failedToSearchCadBillers,
    List<CadBillerViewModel>? cadBillers,
    @Default(false) bool isCheckingSinpe,
    Exception? failedToCheckSinpe,
    @Default('') String sinpeOwnerName,
    @Default(false) bool isAddingRecipient,
    Exception? failedToAddRecipient,
    Exception? failedToSelectRecipient,
  }) = _RecipientsState;
  const RecipientsState._();

  bool get isLoading =>
      isLoadingRecipients ||
      isAddingRecipient ||
      isCheckingSinpe ||
      isSearchingCadBillers;

  bool get hasMoreRecipientsToLoad {
    if (recipients == null || totalRecipients == null) {
      return false;
    }
    return recipients!.length < totalRecipients!;
  }

  Set<RecipientType> get selectableRecipientTypes =>
      allowedRecipientFilters.types.toSet();

  bool get onlyOwnerRecipients => allowedRecipientFilters.isOwner ?? false;

  bool get onlyNonOwnerRecipients => allowedRecipientFilters.isOwner == false;

  Set<String> get availableJurisdictions =>
      selectableRecipientTypes.map((type) => type.jurisdictionCode).toSet();

  String? get selectedJurisdiction {
    if (preferredJurisdiction != null) {
      if (selectableRecipientTypes.any(
        (t) => t.jurisdictionCode == preferredJurisdiction,
      )) {
        return preferredJurisdiction;
      } else {
        // Preferred jurisdiction is not available in the current filters
        // so we fall back to the first available jurisdiction
        return selectableRecipientTypes
            .map((t) => t.jurisdictionCode)
            .firstOrNull;
      }
    }
    return null;
  }

  Set<RecipientType> recipientTypesForJurisdiction(String jurisdiction) {
    return selectableRecipientTypes
        .where((type) => type.jurisdictionCode == jurisdiction)
        .toSet();
  }

  List<RecipientViewModel>? get selectableRecipients {
    // Type/ownership/search/jurisdiction filtering is done server-side; here we
    // only drop duplicate ids so the count stays aligned with totalRecipients.
    if (recipients == null) return null;
    final seen = <String>{};
    return recipients!.where((recipient) => seen.add(recipient.id)).toList();
  }
}
