import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_quick_actions_usecase.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_quick_actions.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryQuickActionsStorage implements QuickActionsStorage {
  String? value;
  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write(String key, String value) async => this.value = value;
  @override
  Future<void> remove(String key) async => value = null;
}

class _MemoryAccessRepository implements ExchangeAccessRepository {
  Map<bool, ExchangeAccess> values = {};
  @override
  Future<Result<Map<bool, ExchangeAccess>, ExchangeAccessFailure>>
  read() async => Ok(values);
  @override
  Future<Result<void, ExchangeAccessFailure>> write(
    Map<bool, ExchangeAccess> value,
  ) async {
    values = Map.of(value);
    return const Ok(null);
  }
}

void main() {
  testWidgets('wallet actions update with access and transfer remains usable', (
    tester,
  ) async {
    final access = ExchangeAccessFacade(repository: _MemoryAccessRepository());
    expect(
      await access.initialize(
        isTestnet: false,
        session: ExchangeSessionFact.anonymous,
      ),
      isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
    );
    final actions = QuickActionsFacade(
      storage: _MemoryQuickActionsStorage(),
      warning: (_) {},
    );
    QuickAction? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [QuickActionsLocalizations.delegate],
        home: Scaffold(
          body: WalletQuickActions(
            quickActions: actions,
            policy: WatchWalletQuickActionsUsecase(access),
            platformAllowsExchange: (_) => true,
            onAction: (_, action) => selected = action,
            onCustomize: (_, _, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer'));
    expect(selected, QuickAction.transfer);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Buy'), findsNothing);
    expect(
      await access.choose(true),
      isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Buy'), findsOneWidget);
    expect(find.text('Trade'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    actions.dispose();
    await access.dispose();
  });
  testWidgets(
    'platform restriction hides and restores a saved exchange favorite',
    (tester) async {
      final access = ExchangeAccessFacade(
        repository: _MemoryAccessRepository(),
      );
      expect(
        await access.initialize(
          isTestnet: false,
          session: ExchangeSessionFact.anonymous,
        ),
        isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      expect(
        await access.choose(true),
        isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      final actions = QuickActionsFacade(
        storage: _MemoryQuickActionsStorage(),
        warning: (_) {},
      );
      await actions.save(
        QuickActionSelection([QuickAction.buy, QuickAction.transfer]),
      );
      final allowed = ValueNotifier(false);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: const [QuickActionsLocalizations.delegate],
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: allowed,
              builder: (context, platformAllowed, _) => WalletQuickActions(
                quickActions: actions,
                policy: WatchWalletQuickActionsUsecase(access),
                platformAllowsExchange: (_) => platformAllowed,
                onAction: (_, _) {},
                onCustomize: (_, _, _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Buy'), findsNothing);
      expect(find.text('Transfer'), findsOneWidget);
      expect((await actions.load())?.actions, [
        QuickAction.buy,
        QuickAction.transfer,
      ]);
      allowed.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Buy'), findsOneWidget);
      expect((await actions.load())?.actions, [
        QuickAction.buy,
        QuickAction.transfer,
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
      allowed.dispose();
      actions.dispose();
      await access.dispose();
    },
  );
}
