import 'package:exchange/exchange.dart';

import 'exchange_access_settings_event.dart';

/// What the user asked the access screen to do.
enum ExchangeAccessAttempt { enable, signOut, retry }

/// The access settings screen: the access state as it is, plus the attempt
/// the user started from here. A failure belongs to its attempt and goes
/// with the next access change (INT-15).
sealed class ExchangeAccessSettingsState {
  const ExchangeAccessSettingsState();
  ExchangeAccess get access;

  /// One attempt at a time: a request while one runs is a stay, and only the
  /// running attempt's result has a pair to land on.
  ExchangeAccessSettingsState next(ExchangeAccessSettingsEvent event) {
    final state = this;
    return switch ((state, event)) {
      // Access changes: the attempt keeps running; anything it left is dropped.
      (
        AccessSettingsWorking(:final attempt),
        AccessSettingsAccessChanged(:final access),
      ) =>
        AccessSettingsWorking(access, attempt),
      (
        AccessSettingsIdle() ||
            AccessSettingsSucceeded() ||
            AccessSettingsFailed(),
        AccessSettingsAccessChanged(:final access),
      ) =>
        sameAccess(access, state.access) ? state : AccessSettingsIdle(access),

      // Requests start an attempt from any state that has none running.
      (
        AccessSettingsWorking(),
        AccessSettingsEnableRequested() ||
            AccessSettingsSignOutRequested() ||
            AccessSettingsRetryRequested(),
      ) =>
        state,
      (
        AccessSettingsIdle() ||
            AccessSettingsSucceeded() ||
            AccessSettingsFailed(),
        AccessSettingsEnableRequested(),
      ) =>
        accessSettingsCanEnable(state.access)
            ? AccessSettingsWorking(state.access, ExchangeAccessAttempt.enable)
            : state,
      (
        AccessSettingsIdle() ||
            AccessSettingsSucceeded() ||
            AccessSettingsFailed(),
        AccessSettingsSignOutRequested(),
      ) =>
        AccessSettingsWorking(state.access, ExchangeAccessAttempt.signOut),
      (
        AccessSettingsIdle() ||
            AccessSettingsSucceeded() ||
            AccessSettingsFailed(),
        AccessSettingsRetryRequested(),
      ) =>
        AccessSettingsWorking(state.access, ExchangeAccessAttempt.retry),

      // Results.
      (
        AccessSettingsWorking(:final attempt),
        AccessSettingsAttemptSucceeded(:final access),
      ) =>
        AccessSettingsSucceeded(access, attempt),
      (
        AccessSettingsWorking(:final access, :final attempt),
        AccessSettingsAttemptFailed(:final failure),
      ) =>
        AccessSettingsFailed(access, attempt, failure),
      (
        AccessSettingsIdle() ||
            AccessSettingsSucceeded() ||
            AccessSettingsFailed(),
        AccessSettingsAttemptSucceeded() || AccessSettingsAttemptFailed(),
      ) =>
        state,
    };
  }
}

final class AccessSettingsIdle extends ExchangeAccessSettingsState {
  const AccessSettingsIdle(this.access);
  @override
  final ExchangeAccess access;

  @override
  bool operator ==(Object other) =>
      other is AccessSettingsIdle && sameAccess(other.access, access);
  @override
  int get hashCode => Object.hash(AccessSettingsIdle, access.runtimeType);
}

final class AccessSettingsWorking extends ExchangeAccessSettingsState {
  const AccessSettingsWorking(this.access, this.attempt);
  @override
  final ExchangeAccess access;
  final ExchangeAccessAttempt attempt;

  @override
  bool operator ==(Object other) =>
      other is AccessSettingsWorking &&
      sameAccess(other.access, access) &&
      other.attempt == attempt;
  @override
  int get hashCode =>
      Object.hash(AccessSettingsWorking, access.runtimeType, attempt);
}

/// Entered once when an attempt succeeds; the screen follows up from here
/// (sign in after enabling, leave after signing out).
final class AccessSettingsSucceeded extends ExchangeAccessSettingsState {
  const AccessSettingsSucceeded(this.access, this.attempt);
  @override
  final ExchangeAccess access;
  final ExchangeAccessAttempt attempt;

  @override
  bool operator ==(Object other) =>
      other is AccessSettingsSucceeded &&
      sameAccess(other.access, access) &&
      other.attempt == attempt;
  @override
  int get hashCode =>
      Object.hash(AccessSettingsSucceeded, access.runtimeType, attempt);
}

final class AccessSettingsFailed extends ExchangeAccessSettingsState {
  const AccessSettingsFailed(this.access, this.attempt, this.failure);
  @override
  final ExchangeAccess access;
  final ExchangeAccessAttempt attempt;
  final ExchangeFailure failure;

  @override
  bool operator ==(Object other) =>
      other is AccessSettingsFailed &&
      sameAccess(other.access, access) &&
      other.attempt == attempt &&
      other.failure == failure;
  @override
  int get hashCode =>
      Object.hash(AccessSettingsFailed, access.runtimeType, attempt, failure);
}

/// Value equality for access states, including the ones without fields.
bool sameAccess(ExchangeAccess a, ExchangeAccess b) => switch (a) {
  ExchangeAccessResolving() => b is ExchangeAccessResolving,
  ExchangeAccessUnreadable() => b is ExchangeAccessUnreadable,
  ExchangeAccessDisabled() => b is ExchangeAccessDisabled,
  ExchangeAccessSignOutIncomplete() => b is ExchangeAccessSignOutIncomplete,
  ExchangeAccessSignedOut() ||
  ExchangeAccessSignedIn() ||
  ExchangeAccessExpiring() ||
  ExchangeAccessCredentialUnreadable() => a == b,
};

/// Enabling is refused while access is still being read and while a
/// sign-out is unfinished (it must finish first).
bool accessSettingsCanEnable(ExchangeAccess access) => switch (access) {
  ExchangeAccessResolving() || ExchangeAccessSignOutIncomplete() => false,
  ExchangeAccessUnreadable() ||
  ExchangeAccessDisabled() ||
  ExchangeAccessSignedOut() ||
  ExchangeAccessSignedIn() ||
  ExchangeAccessExpiring() ||
  ExchangeAccessCredentialUnreadable() => true,
};
