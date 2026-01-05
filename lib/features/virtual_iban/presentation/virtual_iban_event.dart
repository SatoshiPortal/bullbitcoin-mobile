part of 'virtual_iban_bloc.dart';

@freezed
sealed class VirtualIbanEvent with _$VirtualIbanEvent {
  /// Triggered when the bloc is first started.
  /// Loads user summary and checks VIBAN status.
  const factory VirtualIbanEvent.started() = VirtualIbanStarted;

  /// Triggered when user toggles the name confirmation checkbox.
  const factory VirtualIbanEvent.nameConfirmationToggled({
    required bool confirmed,
  }) = VirtualIbanNameConfirmationToggled;

  /// Triggered when user requests to create a new Virtual IBAN.
  const factory VirtualIbanEvent.createRequested() = VirtualIbanCreateRequested;

  /// Triggered to manually refresh the VIBAN status.
  const factory VirtualIbanEvent.refreshRequested() =
      VirtualIbanRefreshRequested;

  /// Internal event triggered by the polling timer.
  const factory VirtualIbanEvent.pollingTicked() = VirtualIbanPollingTicked;

  const VirtualIbanEvent._();
}


