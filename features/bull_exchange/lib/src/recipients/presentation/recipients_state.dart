part of 'recipients_bloc.dart';

@freezed
sealed class RecipientsState with _$RecipientsState {
  const factory RecipientsState({
    Jurisdiction? preferredJurisdiction,
    Jurisdiction? jurisdictionFilter,
    ConfidentialSepaAvailability? confidentialSepaAvailability,
    @Default(false) bool isLoadingConfidentialSepaAvailability,
    ExchangeFailure? failedToLoadConfidentialSepaAvailability,
    AccountOwnerName? accountOwnerName,
    @Default(RecipientType.sepaEur) RecipientType sepaType,
    @Default('') String searchQuery,
    @Default(false) bool isLoadingRecipients,
    ExchangeFailure? failedToLoadRecipients,
    required RecipientFilterCriteria allowedRecipientFilters,
    List<RecipientViewModel>? recipients,
    int? totalRecipients,
    @Default(0) int loadedPages,
    @Default(false) bool isSearchingCadBillers,
    ExchangeFailure? failedToSearchCadBillers,
    List<CadBillerViewModel>? cadBillers,
    @Default(false) bool isCheckingSinpe,
    ExchangeFailure? failedToCheckSinpe,
    @Default('') String sinpeOwnerName,
    @Default(false) bool isAddingRecipient,
    ExchangeFailure? failedToAddRecipient,
    ExchangeFailure? failedToSelectRecipient,
  }) = _RecipientsState;
  const RecipientsState._();

  bool get isLoading =>
      isLoadingConfidentialSepaAvailability ||
      isLoadingRecipients ||
      isAddingRecipient ||
      isCheckingSinpe ||
      isSearchingCadBillers;

  bool get hasMoreRecipientsToLoad {
    if (recipients == null || totalRecipients == null) {
      return false;
    }
    return loadedPages * RecipientsBloc.pageSize < totalRecipients!;
  }

  Set<RecipientType> get selectableRecipientTypes => allowedRecipientFilters
      .types
      .where(
        (type) =>
            type != RecipientType.confidentialSepaEur ||
            (confidentialSepaAvailability != null &&
                confidentialSepaAvailability !=
                    ConfidentialSepaAvailability.unavailable),
      )
      .toSet();

  bool get _offersBothSepaRoutes =>
      selectableRecipientTypes.contains(RecipientType.sepaEur) &&
      selectableRecipientTypes.contains(RecipientType.confidentialSepaEur);

  /// Regular and Confidential SEPA list the same accounts, so a list that
  /// offers both shows one route at a time. The route is a type filter of
  /// the European list: it is offered only there, where it decides every
  /// row shown (under all jurisdictions it would leave the other rails'
  /// rows in a list labelled with a SEPA route).
  bool get canChooseSepaType =>
      _offersBothSepaRoutes &&
      jurisdictionFilter == RecipientType.sepaEur.jurisdiction;

  /// The types the list asks for and shows: the selectable ones in the
  /// selected jurisdiction, with one SEPA route when both are offered (the
  /// chosen one in Europe, regular SEPA otherwise).
  Set<RecipientType> get listedTypes {
    final hiddenSepaType = !_offersBothSepaRoutes
        ? null
        : canChooseSepaType && sepaType == RecipientType.confidentialSepaEur
        ? RecipientType.sepaEur
        : RecipientType.confidentialSepaEur;
    final jurisdiction = jurisdictionFilter;
    return selectableRecipientTypes
        .where(
          (type) =>
              type != hiddenSepaType &&
              (jurisdiction == null || type.jurisdiction == jurisdiction),
        )
        .toSet();
  }

  /// The rows the list shows, always derived from the selected type and
  /// jurisdiction ([listedTypes]), whatever the server returned; with
  /// [strict], also only rows of the allowed owner. Null before the first
  /// page arrived.
  List<RecipientViewModel>? shownRecipients({required bool strict}) {
    final rows = selectableRecipients;
    if (rows == null) return null;
    final types = listedTypes;
    final owner = allowedRecipientFilters.isOwner;
    return rows
        .where(
          (recipient) =>
              types.contains(recipient.type) &&
              (!strict || owner == null || recipient.isOwner == owner),
        )
        .toList();
  }

  bool get onlyOwnerRecipients => allowedRecipientFilters.isOwner ?? false;

  bool get onlyNonOwnerRecipients => allowedRecipientFilters.isOwner == false;

  Set<Jurisdiction> get availableJurisdictions =>
      selectableRecipientTypes.map((type) => type.jurisdiction).toSet();

  Jurisdiction? get selectedJurisdiction {
    if (preferredJurisdiction != null) {
      if (selectableRecipientTypes.any(
        (t) => t.jurisdiction == preferredJurisdiction,
      )) {
        return preferredJurisdiction;
      } else {
        // Preferred jurisdiction is not available in the current filters
        // so we fall back to the first available jurisdiction
        return selectableRecipientTypes.map((t) => t.jurisdiction).firstOrNull;
      }
    }
    return null;
  }

  Set<RecipientType> recipientTypesForJurisdiction(Jurisdiction jurisdiction) {
    return selectableRecipientTypes
        .where((type) => type.jurisdiction == jurisdiction)
        .toSet();
  }

  List<RecipientViewModel>? get selectableRecipients {
    final loaded = recipients;
    if (loaded == null) return null;
    final seen = <String>{};
    return loaded.where((recipient) => seen.add(recipient.id)).toList();
  }
}
