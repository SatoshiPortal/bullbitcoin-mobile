import 'package:exchange/exchange.dart';

sealed class ExchangeAccessSettingsEvent {
  const ExchangeAccessSettingsEvent();
}

final class AccessSettingsAccessChanged extends ExchangeAccessSettingsEvent {
  const AccessSettingsAccessChanged(this.access);
  final ExchangeAccess access;
}

final class AccessSettingsEnableRequested extends ExchangeAccessSettingsEvent {
  const AccessSettingsEnableRequested();
}

final class AccessSettingsSignOutRequested extends ExchangeAccessSettingsEvent {
  const AccessSettingsSignOutRequested();
}

final class AccessSettingsRetryRequested extends ExchangeAccessSettingsEvent {
  const AccessSettingsRetryRequested();
}

/// The running attempt ended well; [access] is the access read right after.
final class AccessSettingsAttemptSucceeded extends ExchangeAccessSettingsEvent {
  const AccessSettingsAttemptSucceeded(this.access);
  final ExchangeAccess access;
}

final class AccessSettingsAttemptFailed extends ExchangeAccessSettingsEvent {
  const AccessSettingsAttemptFailed(this.failure);
  final ExchangeFailure failure;
}
