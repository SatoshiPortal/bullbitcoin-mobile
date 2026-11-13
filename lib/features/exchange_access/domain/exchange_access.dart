enum ExchangeAccessChoice { unset, enabled, disabled }

enum ExchangeSessionFact {
  resolving,
  anonymous,
  authenticated,
  expired,
  unavailable,
  networkUnavailable,
}

enum ExchangeAccessTransition { none, enabling, disabling }

enum ExchangeAccessOutcome { applied, authenticationRequired, cancelled, stale }

class ExchangeAccess {
  const ExchangeAccess({
    this.choice = ExchangeAccessChoice.unset,
    this.session = ExchangeSessionFact.resolving,
    this.transition = ExchangeAccessTransition.none,
    this.revision = 0,
    this.isStale = false,
    this.lastKnownAuthenticated = false,
  });

  final ExchangeAccessChoice choice;
  final ExchangeSessionFact session;
  final ExchangeAccessTransition transition;
  final int revision;
  final bool isStale;
  final bool lastKnownAuthenticated;

  bool get enabledForHome =>
      choice == ExchangeAccessChoice.enabled &&
      transition != ExchangeAccessTransition.disabling;

  bool get canUseAuthenticatedExchange =>
      enabledForHome && session == ExchangeSessionFact.authenticated;

  ExchangeAccess copyWith({
    ExchangeAccessChoice? choice,
    ExchangeSessionFact? session,
    ExchangeAccessTransition? transition,
    int? revision,
    bool? isStale,
    bool? lastKnownAuthenticated,
  }) => ExchangeAccess(
    choice: choice ?? this.choice,
    session: session ?? this.session,
    transition: transition ?? this.transition,
    revision: revision ?? this.revision,
    isStale: isStale ?? this.isStale,
    lastKnownAuthenticated:
        lastKnownAuthenticated ?? this.lastKnownAuthenticated,
  );
}
