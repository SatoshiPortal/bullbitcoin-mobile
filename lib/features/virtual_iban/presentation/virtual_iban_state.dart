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
    required VirtualIbanLocation location,
    @Default(false) bool nameConfirmed,
    @Default(false) bool isCreating,
    Exception? error,
  }) = VirtualIbanNotSubmittedState;

  /// State when VIBAN has been created but not yet activated.
  /// Shows the pending/activating screen and polls for activation.
  const factory VirtualIbanState.pending({
    required VirtualIbanRecipient recipient,
    required UserSummary userSummary,
    required VirtualIbanLocation location,
    @Default(false) bool isPolling,
  }) = VirtualIbanPendingState;

  /// State when VIBAN is fully activated.
  /// Shows the success screen or details screen.
  const factory VirtualIbanState.active({
    required VirtualIbanRecipient recipient,
    required UserSummary userSummary,
    required VirtualIbanLocation location,
  }) = VirtualIbanActiveState;

  /// Error state when something goes wrong.
  const factory VirtualIbanState.error({required Exception exception}) =
      VirtualIbanErrorState;

  const VirtualIbanState._();

  /// Returns the user's full name from the user summary, if available.
  String? get userFullName {
    return when(
      initial: () => null,
      loading: () => null,
      notSubmitted:
          (userSummary, location, nameConfirmed, isCreating, error) =>
              '${userSummary.profile.firstName} ${userSummary.profile.lastName}'
                  .trim(),
      pending:
          (recipient, userSummary, location, isPolling) =>
              '${userSummary.profile.firstName} ${userSummary.profile.lastName}'
                  .trim(),
      active:
          (recipient, userSummary, location) =>
              '${userSummary.profile.firstName} ${userSummary.profile.lastName}'
                  .trim(),
      error: (exception) => null,
    );
  }

  /// Returns the location context, if available.
  VirtualIbanLocation? get location {
    return when(
      initial: () => null,
      loading: () => null,
      notSubmitted:
          (userSummary, location, nameConfirmed, isCreating, error) => location,
      pending: (recipient, userSummary, location, isPolling) => location,
      active: (recipient, userSummary, location) => location,
      error: (exception) => null,
    );
  }
}


