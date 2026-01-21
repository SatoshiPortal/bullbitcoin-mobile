part of 'recipients_bloc.dart';

@freezed
sealed class RecipientsState with _$RecipientsState {
  const factory RecipientsState({
    @Default(false) bool isLoadingRecipients,
    Exception? failedToLoadRecipients,
    required AllowedRecipientFiltersViewModel allowedRecipientFilters,
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
    RecipientViewModel? selectedRecipient,
    @Default(false) bool isHandlingSelectedRecipient,
    Exception? failedToHandleSelectedRecipient,
    // Virtual IBAN step flow fields
    @Default(RecipientFlowStep.selectType) RecipientFlowStep currentStep,
    @Default(false) bool hasActiveVirtualIban,
    // Selected type and jurisdiction from Step 1 (used in Step 2 to show the correct form)
    RecipientType? selectedRecipientType,
    String? selectedJurisdiction,
  }) = _RecipientsState;
  const RecipientsState._();

  bool get isLoading =>
      isLoadingRecipients ||
      isAddingRecipient ||
      isCheckingSinpe ||
      isSearchingCadBillers ||
      isHandlingSelectedRecipient;

  bool get hasMoreRecipientsToLoad {
    if (recipients == null || totalRecipients == null) {
      return false;
    }
    return recipients!.length < totalRecipients!;
  }

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
    // Note: FR_VIRTUAL_ACCOUNT is excluded as it's a special system-created recipient
    // for Confidential SEPA and should not appear in normal recipient lists.
    var filtered =
        recipients
            ?.where(
              (recipient) =>
                  recipient.type != RecipientType.frVirtualAccount &&
                  selectableRecipientTypes.any(
                    (type) => type == recipient.type,
                  ) &&
                  !(onlyOwnerRecipients && !(recipient.isOwner == true) ||
                      onlyNonOwnerRecipients && !(recipient.isOwner == false)),
            )
            .toList();

    if (filtered == null) return null;

    // Apply Virtual IBAN filtering when in VIBAN-eligible location with active VIBAN
    // This groups recipients by IBAN and prefers frPayee over cjPayee for same IBAN
    final isVibanEligible =
        allowedRecipientFilters.location.isVirtualIbanEligible;
    if (isVibanEligible && hasActiveVirtualIban) {
      filtered = _filterForVirtualIban(filtered);
    }

    // Remove duplicates based on recipient ID
    final seen = <String>{};
    return filtered.where((recipient) => seen.add(recipient.id)).toList();
  }

  /// Filters and deduplicates recipients for Virtual IBAN mode.
  /// For recipients with the same IBAN, frPayee is preferred over cjPayee.
  /// This is a presentation concern, so the logic lives here rather than
  /// in a usecase.
  List<RecipientViewModel> _filterForVirtualIban(
    List<RecipientViewModel> recipients,
  ) {
    // Filter to only show recipients with isOwner=true
    final ownerRecipients =
        recipients.where((r) => r.isOwner == true).toList();

    // Group recipients by IBAN
    final ibanGroups = <String, List<RecipientViewModel>>{};
    final recipientsWithoutIban = <RecipientViewModel>[];

    for (final recipient in ownerRecipients) {
      final iban = recipient.iban;
      if (iban != null && iban.isNotEmpty) {
        ibanGroups.putIfAbsent(iban, () => []).add(recipient);
      } else {
        // Keep track of recipients without IBAN separately
        recipientsWithoutIban.add(recipient);
      }
    }

    // For each IBAN group, if there are both cjPayee and frPayee,
    // keep only the frPayee recipient
    final result = <RecipientViewModel>[];
    for (final group in ibanGroups.values) {
      final frPayees =
          group.where((r) => r.type == RecipientType.frPayee).toList();
      final cjPayees =
          group.where((r) => r.type == RecipientType.cjPayee).toList();

      if (frPayees.isNotEmpty && cjPayees.isNotEmpty) {
        // If both exist, only add frPayee recipients (prefer VIBAN)
        result.addAll(frPayees);
      } else {
        // Otherwise, add all recipients in the group
        result.addAll(group);
      }
    }

    // Add recipients without IBAN (shouldn't happen for cjPayee/frPayee, but just in case)
    result.addAll(recipientsWithoutIban);

    return result;
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
