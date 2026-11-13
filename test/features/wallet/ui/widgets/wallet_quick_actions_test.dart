import 'dart:async';

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
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transfer'));
      expect(selected, QuickAction.transfer);
      expect(find.text('Buy'), findsNothing);
      changes.add(true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Buy'), findsOneWidget);
      Navigator.of(tester.element(find.text('Buy'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Transfer'), findsOneWidget);
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
      QuickActionSelection([QuickAction.buy, QuickAction.transfer]),
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buy'), findsNothing);
    expect(find.text('Transfer'), findsOneWidget);
    changes.add(true);
    await tester.pumpAndSettle();
    expect(find.text('Buy'), findsOneWidget);
    expect(actions.state.selection?.actions, [
      QuickAction.buy,
      QuickAction.transfer,
    ]);
    changes.add(false);
    await tester.pumpAndSettle();
    expect(find.text('Buy'), findsNothing);
    expect(actions.state.selection?.actions, [
      QuickAction.buy,
      QuickAction.transfer,
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
