import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_quick_actions_usecase.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled exchange keeps wallet actions available', () {
    final policy = WalletQuickActionsPolicy(
      const ExchangeAccess(choice: ExchangeAccessChoice.disabled),
    );
    expect(policy.available(platformAllowsExchange: true), {
      QuickAction.transfer,
      QuickAction.map,
      QuickAction.settings,
      QuickAction.history,
      QuickAction.support,
      QuickAction.priceHistory,
    });
    expect(policy.defaults, [
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.history,
      QuickAction.settings,
    ]);
  });

  test(
    'enabled and signed-in accounts offer all actions with wallet defaults',
    () {
      final policy = WalletQuickActionsPolicy(
        const ExchangeAccess(
          choice: ExchangeAccessChoice.enabled,
          lastKnownAuthenticated: true,
        ),
      );
      expect(
        policy.available(platformAllowsExchange: true),
        QuickAction.values.toSet(),
      );
      expect(policy.defaults, [
        QuickAction.map,
        QuickAction.transfer,
        QuickAction.history,
        QuickAction.settings,
      ]);
      expect(
        policy.available(platformAllowsExchange: true),
        contains(QuickAction.transfer),
      );
    },
  );

  test('enabled anonymous accounts retain wallet-first defaults', () {
    final policy = WalletQuickActionsPolicy(
      const ExchangeAccess(choice: ExchangeAccessChoice.enabled),
    );
    expect(
      policy.available(platformAllowsExchange: true),
      containsAll([QuickAction.buy, QuickAction.transfer]),
    );
    expect(policy.defaults, [
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.history,
      QuickAction.settings,
    ]);
  });

  test(
    'disabling exchange removes account actions while retaining transfer',
    () {
      final policy = WalletQuickActionsPolicy(
        const ExchangeAccess(
          choice: ExchangeAccessChoice.enabled,
          transition: ExchangeAccessTransition.disabling,
          lastKnownAuthenticated: true,
        ),
      );
      expect(
        policy.available(platformAllowsExchange: true),
        contains(QuickAction.transfer),
      );
      expect(
        policy.available(platformAllowsExchange: true),
        isNot(contains(QuickAction.buy)),
      );
      expect(
        policy.available(platformAllowsExchange: true),
        isNot(contains(QuickAction.exchange)),
      );
    },
  );
  test(
    'iOS without superuser hides exchange while preserving wallet actions',
    () {
      final policy = WalletQuickActionsPolicy(
        const ExchangeAccess(choice: ExchangeAccessChoice.enabled),
      );
      expect(policy.available(platformAllowsExchange: false), {
        QuickAction.map,
        QuickAction.transfer,
        QuickAction.history,
        QuickAction.settings,
        QuickAction.support,
        QuickAction.priceHistory,
      });
      expect(
        policy.available(platformAllowsExchange: true),
        QuickAction.values.toSet(),
      );
    },
  );
}
