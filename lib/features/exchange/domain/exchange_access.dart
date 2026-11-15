sealed class ExchangeAccess {
  const ExchangeAccess();
}

final class ExchangeAccessResolving extends ExchangeAccess {
  const ExchangeAccessResolving();
}

final class ExchangeAccessUnreadable extends ExchangeAccess {
  const ExchangeAccessUnreadable();
}

final class ExchangeAccessDisabled extends ExchangeAccess {
  const ExchangeAccessDisabled();
}

final class ExchangeAccessSignOutIncomplete extends ExchangeAccess {
  const ExchangeAccessSignOutIncomplete();
}

enum ExchangeAccessSession { signedOut, signedIn, unreadable }

final class ExchangeAccessEnabled extends ExchangeAccess {
  const ExchangeAccessEnabled(this.session);
  final ExchangeAccessSession session;
}
