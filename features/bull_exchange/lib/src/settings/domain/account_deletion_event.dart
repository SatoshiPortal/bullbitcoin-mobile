import 'package:exchange/exchange.dart';

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
