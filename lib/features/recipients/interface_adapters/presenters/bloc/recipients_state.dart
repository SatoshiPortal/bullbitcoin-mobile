part of 'recipients_bloc.dart';

@freezed
sealed class RecipientsState with _$RecipientsState {
  const factory RecipientsState({
    @Default(false) bool isLoadingRecipients,
    @Default(RecipientType.values) List<RecipientType> selectableRecipientTypes,
    @Default([]) List<RecipientViewModel> recipients,
    @Default(false) bool isAddingRecipient,
    @Default(false) bool isCheckingSinpe,
    @Default('') String sinpeCheckResult,
    @Default([]) List<CadBillerViewModel> cadBillers,
    @Default(false) bool isSearchingCadBillers,
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
}
