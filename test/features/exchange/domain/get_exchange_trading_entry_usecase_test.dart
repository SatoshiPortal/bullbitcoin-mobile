import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_trading_entry_usecase.dart';
import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trading entry respects choice, session, transition and platform', () {
    const cases = <(ExchangeAccess, bool, ExchangeTradingEntry)>[
      (
        ExchangeAccess(
          choice: ExchangeAccessChoice.enabled,
          session: ExchangeSessionFact.authenticated,
        ),
        true,
        ExchangeTradingEntry.allowed,
      ),
      (
        ExchangeAccess(
          choice: ExchangeAccessChoice.enabled,
          session: ExchangeSessionFact.anonymous,
        ),
        true,
        ExchangeTradingEntry.authenticationRequired,
      ),
      (
        ExchangeAccess(
          choice: ExchangeAccessChoice.disabled,
          session: ExchangeSessionFact.authenticated,
        ),
        true,
        ExchangeTradingEntry.unavailable,
      ),
      (
        ExchangeAccess(
          choice: ExchangeAccessChoice.unset,
          session: ExchangeSessionFact.anonymous,
        ),
        true,
        ExchangeTradingEntry.unavailable,
      ),
      (
        ExchangeAccess(
          choice: ExchangeAccessChoice.enabled,
          session: ExchangeSessionFact.resolving,
        ),
        true,
        ExchangeTradingEntry.unavailable,
      ),
      (
        ExchangeAccess(
          choice: ExchangeAccessChoice.enabled,
          session: ExchangeSessionFact.unavailable,
        ),
        true,
        ExchangeTradingEntry.unavailable,
      ),
      (
        ExchangeAccess(
          choice: ExchangeAccessChoice.enabled,
          session: ExchangeSessionFact.expired,
        ),
        true,
        ExchangeTradingEntry.unavailable,
      ),
      (
        ExchangeAccess(
          choice: ExchangeAccessChoice.enabled,
          session: ExchangeSessionFact.authenticated,
          transition: ExchangeAccessTransition.disabling,
        ),
        true,
        ExchangeTradingEntry.unavailable,
      ),
      (
        ExchangeAccess(
          choice: ExchangeAccessChoice.enabled,
          session: ExchangeSessionFact.authenticated,
        ),
        false,
        ExchangeTradingEntry.unavailable,
      ),
      (
        ExchangeAccess(
          choice: ExchangeAccessChoice.enabled,
          session: ExchangeSessionFact.anonymous,
        ),
        false,
        ExchangeTradingEntry.unavailable,
      ),
    ];
    for (final (access, allowed, expected) in cases) {
      expect(
        GetExchangeTradingEntryUsecase.resolve(
          access: access,
          platformAllowed: allowed,
        ),
        expected,
      );
    }
  });
}
