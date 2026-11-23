import 'package:exchange/exchange.dart';

/// Account deletion from exchange settings (B16): one request at a time.
sealed class AccountDeletionState {
  const AccountDeletionState();
}

final class AccountDeletionIdle extends AccountDeletionState {
  const AccountDeletionIdle();
}

final class AccountDeletionRequesting extends AccountDeletionState {
  const AccountDeletionRequesting();
}

/// The request reached support and this device signed out.
final class AccountDeletionRequested extends AccountDeletionState {
  const AccountDeletionRequested();
}

final class AccountDeletionFailed extends AccountDeletionState {
  const AccountDeletionFailed(this.failure);
  final ExchangeFailure failure;

  @override
  bool operator ==(Object other) =>
      other is AccountDeletionFailed && other.failure == failure;
  @override
  int get hashCode => Object.hash(AccountDeletionFailed, failure);
}

sealed class AccountDeletionEvent {
  const AccountDeletionEvent();
}

/// The user confirmed the deletion sheet.
final class AccountDeletionConfirmed extends AccountDeletionEvent {
  const AccountDeletionConfirmed();
}

final class AccountDeletionSent extends AccountDeletionEvent {
  const AccountDeletionSent();
}

/// The session changed while the request ran; nothing to report on this
/// account any more.
final class AccountDeletionStale extends AccountDeletionEvent {
  const AccountDeletionStale();
}

final class AccountDeletionNotSent extends AccountDeletionEvent {
  const AccountDeletionNotSent(this.failure);
  final ExchangeFailure failure;
}

AccountDeletionState transitionAccountDeletion(
  AccountDeletionState state,
  AccountDeletionEvent event,
) => switch ((state, event)) {
  (
    AccountDeletionIdle() || AccountDeletionFailed(),
    AccountDeletionConfirmed(),
  ) =>
    const AccountDeletionRequesting(),
  // A second request while one runs, or after it was sent, is a stay.
  (
    AccountDeletionRequesting() || AccountDeletionRequested(),
    AccountDeletionConfirmed(),
  ) =>
    state,
  (AccountDeletionRequesting(), AccountDeletionSent()) =>
    const AccountDeletionRequested(),
  (AccountDeletionRequesting(), AccountDeletionStale()) =>
    const AccountDeletionIdle(),
  (AccountDeletionRequesting(), AccountDeletionNotSent(:final failure)) =>
    AccountDeletionFailed(failure),
  // Results without a running request have nothing to land on.
  (
    AccountDeletionIdle() ||
        AccountDeletionRequested() ||
        AccountDeletionFailed(),
    AccountDeletionSent() || AccountDeletionStale() || AccountDeletionNotSent(),
  ) =>
    state,
};
