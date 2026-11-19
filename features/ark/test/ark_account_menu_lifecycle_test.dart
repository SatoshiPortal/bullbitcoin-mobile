// Home action-sheet lifecycle: a callback kept from a dismissed or covered
// sheet must neither pop a later route nor dispatch Board.
import 'dart:async';

import 'package:bull_ui/bull_ui.dart' show BullBottomSheet;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

import 'ark_account_screen_test.dart' as wallet;
import 'ark_information_widget_test.dart' show app;

void main() {
  testWidgets('dismissed Home menu callback cannot pop a replacement route', (
    tester,
  ) async {
    final calls = <String>[];
    final cubit = wallet.controller(
      wallet.Client()..snapshot = Ok(wallet.observation()),
    );
    await tester.pumpWidget(app(wallet.screen(cubit, calls)));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await wallet.openActions(tester);
    final oldBoard = wallet.button(tester, 'Board to Ark').onPressed;
    navigator.pop();
    await tester.pumpAndSettle();
    var replacementPopped = false;
    unawaited(
      navigator
          .push<Object?>(
            MaterialPageRoute<Object?>(
              builder: (_) => const Scaffold(body: Text('replacement route')),
            ),
          )
          .then((_) {
            replacementPopped = true;
          }),
    );
    await tester.pumpAndSettle();
    oldBoard();
    await tester.pumpAndSettle();
    expect(replacementPopped, false);
    expect(find.text('replacement route'), findsOneWidget);
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
    navigator.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('dismissed Home menu cannot inject Board into a new sheet', (
    tester,
  ) async {
    final calls = <String>[];
    final cubit = wallet.controller(
      wallet.Client()..snapshot = Ok(wallet.observation()),
    );
    await tester.pumpWidget(app(wallet.screen(cubit, calls)));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await wallet.openActions(tester);
    final oldBoard = wallet.button(tester, 'Board to Ark').onPressed;
    navigator.pop();
    await tester.pumpAndSettle();
    await wallet.openActions(tester);
    expect(find.byType(BullBottomSheet), findsOneWidget);
    oldBoard();
    await tester.pumpAndSettle();
    expect(find.byType(BullBottomSheet), findsOneWidget);
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
    navigator.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('a mounted sheet covered by another route ignores its action', (
    tester,
  ) async {
    final calls = <String>[];
    final cubit = wallet.controller(
      wallet.Client()..snapshot = Ok(wallet.observation()),
    );
    await tester.pumpWidget(app(wallet.screen(cubit, calls)));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await wallet.openActions(tester);
    final coveredBoard = wallet.button(tester, 'Board to Ark').onPressed;
    unawaited(
      navigator.push<Object?>(
        MaterialPageRoute<Object?>(
          builder: (_) => const Scaffold(body: Text('covering route')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    coveredBoard();
    await tester.pumpAndSettle();
    expect(find.text('covering route'), findsOneWidget);
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('the current sheet dispatches Board exactly once', (
    tester,
  ) async {
    final calls = <String>[];
    final cubit = wallet.controller(
      wallet.Client()..snapshot = Ok(wallet.observation()),
    );
    await tester.pumpWidget(app(wallet.screen(cubit, calls)));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await wallet.openActions(tester);
    final oldBoard = wallet.button(tester, 'Board to Ark').onPressed;
    navigator.pop();
    await tester.pumpAndSettle();
    await wallet.openActions(tester);
    final currentBoard = wallet.button(tester, 'Board to Ark').onPressed;
    oldBoard();
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    currentBoard();
    currentBoard();
    await tester.pumpAndSettle();
    expect(calls, ['board']);
    expect(find.byType(BullBottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
