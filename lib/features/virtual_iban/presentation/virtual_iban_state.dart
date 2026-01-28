part of 'virtual_iban_bloc.dart';

@freezed
sealed class VirtualIbanState with _$VirtualIbanState {
  /// Initial state before any data is loaded.
  const factory VirtualIbanState.initial() = VirtualIbanInitialState;

  /// Loading state while fetching VIBAN status.
  const factory VirtualIbanState.loading() = VirtualIbanLoadingState;

  /// State when no VIBAN has been created yet.
  /// Shows the activation intro form.
  const factory VirtualIbanState.notSubmitted({
    required UserSummary userSummary,
    @Default(false) bool nameConfirmed,
    @Default(false) bool isCreating,
    Exception? error,
  }) = VirtualIbanNotSubmittedState;

  /// State when VIBAN has been created but not yet activated.
  /// Shows the pending/activating screen and polls for activation.
  const factory VirtualIbanState.pending({
    required VirtualIbanRecipient recipient,
    required UserSummary userSummary,
    @Default(false) bool isPolling,
  }) = VirtualIbanPendingState;

  /// State when VIBAN is fully activated.
  /// Shows the success screen or details screen.
  const factory VirtualIbanState.active({
    required VirtualIbanRecipient recipient,
    required UserSummary userSummary,
  }) = VirtualIbanActiveState;

  /// Error state when something goes wrong.
  const factory VirtualIbanState.error({required Exception exception}) =
      VirtualIbanErrorState;

  const VirtualIbanState._();

  // ============ Convenience Getters (like BB-Exchange's EuVibanState) ============

  /// Whether VIBAN is fully activated and ready to use.
  bool get isActive => this is VirtualIbanActiveState;

  /// Whether VIBAN has been submitted but not yet activated.
  bool get isPending => this is VirtualIbanPendingState;

  /// Whether no VIBAN has been created yet.
  bool get isNotSubmitted => this is VirtualIbanNotSubmittedState;

  /// Whether we're currently loading VIBAN status.
  bool get isLoading => this is VirtualIbanLoadingState;

  /// Whether there's an error state.
  bool get hasError => this is VirtualIbanErrorState;

  /// Returns the VIBAN recipient if available (active or pending state).
  VirtualIbanRecipient? get recipient {
    return maybeWhen(
      active: (recipient, _) => recipient,
      pending: (recipient, _, _) => recipient,
      orElse: () => null,
    );
  }

  /// Returns the user summary if available.
  UserSummary? get userSummary {
    return maybeWhen(
      notSubmitted: (userSummary, _, _, _) => userSummary,
      pending: (_, userSummary, _) => userSummary,
      active: (_, userSummary) => userSummary,
      orElse: () => null,
    );
  }

  /// Returns the user's full name from the user summary, if available.
  String? get userFullName {
    final summary = userSummary;
    if (summary == null) return null;
    return '${summary.profile.firstName} ${summary.profile.lastName}'.trim();
  }
}
