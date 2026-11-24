/// The app's entry to the exchange: the public API of `bull_exchange` and the
/// app's own exchange wiring.
library;

export 'package:bull_exchange/bull_exchange.dart'
    show ExchangeAccount, ExchangeFacade, ExchangeFailureL10n;
export 'package:primitives/primitives.dart' show Err, Ok, Result;

export '../exchange_locator.dart' show ExchangeLocator;
export '../ui/exchange_router.dart'
    show ExchangeRoute, ExchangeRouter, ExchangeRouterConfig;
export '../ui/exchange_scope.dart'
    show ExchangeAccessBuilder, ExchangeScope, ExchangeSessionBuilder;
