import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exchange_prompt_cubit_test.dart' show KeyedStorage;
import 'quick_actions_test.dart' show MemoryStorage;

Future<void> _mount(
  WidgetTester tester, {
  ExchangePromptCubit? prompt,
  VoidCallback? onActivateExchange,
}) async {
  final cubit = createQuickActionsCubit(
    storage: MemoryStorage(),
    warning: (_) {},
    exchangeVisible: Stream.value(false),
  );
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: const [QuickActionsLocalizations.delegate],
      home: Scaffold(
        body: QuickActionsRow(
          cubit: cubit,
          onAction: (_) {},
          onCustomize: () {},
          exchangePrompt: prompt,
          onActivateExchange: onActivateExchange,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ExchangePromptCubit _prompt(KeyedStorage storage, {bool offered = true}) {
  final prompt = createExchangePromptCubit(
    storage: storage,
    warning: (_) {},
    offered: Stream.value(offered),
  );
  addTearDown(prompt.close);
  return prompt;
}

Future<void> _openMore(WidgetTester tester) async {
  await tester.tap(find.text('More'));
  await tester.pumpAndSettle();
}

QuickActionsLocalizations _l10n(WidgetTester tester) =>
    QuickActionsLocalizations.of(tester.element(find.byType(QuickActionsRow)));

void main() {
  testWidgets('More shows the exchange prompt and Activate closes the sheet', (
    tester,
  ) async {
    var activations = 0;
    await _mount(
      tester,
      prompt: _prompt(KeyedStorage()),
      onActivateExchange: () => activations++,
    );
    final l10n = _l10n(tester);
    expect(find.text(l10n.exchangeOff), findsNothing);
    await _openMore(tester);
    expect(find.text(l10n.exchangeOff), findsOneWidget);
    expect(find.byTooltip(l10n.dismiss), findsOneWidget);
    expect(activations, 0);
    await tester.tap(find.text(l10n.activate));
    await tester.pumpAndSettle();
    expect(activations, 1);
    expect(find.text(l10n.edit), findsNothing);
    expect(find.text(l10n.exchangeOff), findsNothing);
  });

  testWidgets('dismissing hides the prompt and it stays hidden on reopen', (
    tester,
  ) async {
    final storage = KeyedStorage();
    var activations = 0;
    await _mount(
      tester,
      prompt: _prompt(storage),
      onActivateExchange: () => activations++,
    );
    final l10n = _l10n(tester);
    await _openMore(tester);
    expect(find.text(l10n.exchangeOff), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.dismiss));
    await tester.pumpAndSettle();
    expect(find.text(l10n.exchangeOff), findsNothing);
    expect(find.text(l10n.activate), findsNothing);
    expect(find.text(l10n.edit), findsOneWidget);
    expect(storage.values, {'quick_actions_exchange_prompt_dismissed': 'true'});
    await tester.tap(find.byTooltip(l10n.close));
    await tester.pumpAndSettle();
    expect(find.text(l10n.edit), findsNothing);
    await _openMore(tester);
    expect(find.text(l10n.edit), findsOneWidget);
    expect(find.text(l10n.exchangeOff), findsNothing);
    expect(activations, 0);
  });

  testWidgets('no prompt while the host does not offer the exchange', (
    tester,
  ) async {
    await _mount(tester, prompt: _prompt(KeyedStorage(), offered: false));
    final l10n = _l10n(tester);
    await _openMore(tester);
    expect(find.text(l10n.edit), findsOneWidget);
    expect(find.text(l10n.exchangeOff), findsNothing);
  });

  testWidgets('no prompt without an exchange prompt cubit', (tester) async {
    await _mount(tester);
    final l10n = _l10n(tester);
    await _openMore(tester);
    expect(find.text(l10n.edit), findsOneWidget);
    expect(find.text(l10n.exchangeOff), findsNothing);
    expect(find.text(l10n.activate), findsNothing);
    expect(find.byTooltip(l10n.dismiss), findsNothing);
  });
}
