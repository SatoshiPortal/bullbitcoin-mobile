import 'dart:async';

import 'package:overview/overview.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
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

void main() {
  testWidgets(
    'wallet actions update with visibility and transfer remains usable',
    (tester) async {
      final changes = StreamController<bool>();
      final actions = createQuickActionsCubit(
        storage: _MemoryQuickActionsStorage(),
        warning: (_) {},
        exchangeVisible: changes.stream,
      );
      addTearDown(() async {
        await actions.close();
        await changes.close();
      });
      changes.add(false);
      QuickAction? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: const [QuickActionsLocalizations.delegate],
          home: Scaffold(
            body: WalletQuickActions(
              quickActions: actions,
              onAction: (_, action) => selected = action,
              onCustomize: (_) {},
              exchangePrompt: createExchangePromptCubit(
                storage: _MemoryQuickActionsStorage(),
                warning: (_) {},
                offered: const Stream.empty(),
              ),
              onActivateExchange: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Swap'));
      expect(selected, QuickAction.transfer);
      expect(find.text('Pay'), findsNothing);
      changes.add(true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Pay'), findsOneWidget);
      Navigator.of(tester.element(find.text('Pay'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Swap'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('visibility changes preserve a saved exchange favorite', (
    tester,
  ) async {
    final changes = StreamController<bool>();
    final actions = createQuickActionsCubit(
      storage: _MemoryQuickActionsStorage(),
      warning: (_) {},
      exchangeVisible: changes.stream,
    );
    addTearDown(() async {
      await actions.close();
      await changes.close();
    });
    changes.add(false);
    await actions.save(
      QuickActionSelection([QuickAction.pay, QuickAction.transfer]),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [QuickActionsLocalizations.delegate],
        home: Scaffold(
          body: WalletQuickActions(
            quickActions: actions,
            onAction: (_, _) {},
            onCustomize: (_) {},
            exchangePrompt: createExchangePromptCubit(
              storage: _MemoryQuickActionsStorage(),
              warning: (_) {},
              offered: const Stream.empty(),
            ),
            onActivateExchange: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pay'), findsNothing);
    expect(find.text('Swap'), findsOneWidget);
    changes.add(true);
    await tester.pumpAndSettle();
    expect(find.text('Pay'), findsOneWidget);
    expect(actions.state.selection?.actions, [
      QuickAction.pay,
      QuickAction.transfer,
    ]);
    changes.add(false);
    await tester.pumpAndSettle();
    expect(find.text('Pay'), findsNothing);
    expect(actions.state.selection?.actions, [
      QuickAction.pay,
      QuickAction.transfer,
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
