part of 'recipients_bloc.dart';

@freezed
sealed class RecipientsState with _$RecipientsState {
  const factory RecipientsState({
    String? preferredJurisdiction,
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
    // Apply filters to the full recipient list based on the allowed recipient types
    // and ownership criteria.
    final filtered = recipients
        ?.where(
          (recipient) =>
              selectableRecipientTypes.any((type) => type == recipient.type) &&
              !(onlyOwnerRecipients && !(recipient.isOwner == true) ||
                  onlyNonOwnerRecipients && !(recipient.isOwner == false)),
        )
        .toList();

    // Remove duplicates based on recipient ID
    if (filtered == null) return null;
    final seen = <String>{};
    return filtered.where((recipient) => seen.add(recipient.id)).toList();
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
