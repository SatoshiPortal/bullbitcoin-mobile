import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/passphrase_wallet/ui/passphrase_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('enters every printable ASCII character', (tester) async {
    final key = GlobalKey<PassphraseInputState>();
    await _pump(tester, key: key);

    const lowerCase = 'qwertyuiopasdfghjklzxcvbnm';
    for (final character in lowerCase.characters) {
      await tester.tap(find.text(character));
    }

    await tester.tap(find.text('ABC'));
    await tester.pump();
    for (final character in lowerCase.toUpperCase().characters) {
      await tester.tap(find.text(character));
    }

    await tester.tap(find.text('#+='));
    await tester.pump();
    const symbols = '1234567890!@#\$%^&*()-_=+[]{}\\|;:\'",<.>/?`~';
    for (final character in symbols.characters) {
      await tester.tap(find.text(character));
    }
    await tester.tap(find.text('Space'));

    expect(
      key.currentState!.takeValue(),
      '$lowerCase${lowerCase.toUpperCase()}$symbols ',
    );
    expect(find.text(lowerCase), findsNothing);
  });

  testWidgets('does not expose an editable text field', (tester) async {
    await _pump(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('a hardware keyboard cannot reach the buffer', (tester) async {
    final key = GlobalKey<PassphraseInputState>();
    await _pump(tester, key: key);

    for (final logicalKey in [
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.space,
    ]) {
      await tester.sendKeyEvent(logicalKey);
      await tester.pump();
    }

    expect(key.currentState!.takeValue(), isEmpty);
  });

  testWidgets('offers no paste, autofill or selection affordance', (
    tester,
  ) async {
    await _pump(tester);
    await _type(tester, 'abc');

    // Without an EditableText there is no selection, no paste toolbar and no
    // autofill client for the platform to fill; these assert that nothing
    // reintroduced one alongside the in-app keyboard.
    expect(find.byType(AutofillGroup), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);

    await tester.longPress(find.text('abc'));
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    expect(find.text('Paste'), findsNothing);
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('starts visible and obscures on request', (tester) async {
    await _pump(tester);
    await _type(tester, 'abc');

    expect(find.text('abc'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    expect(find.text('abc'), findsNothing);
    expect(find.text('•••'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    expect(find.text('abc'), findsOneWidget);
  });

  testWidgets('the semantics tree carries no part of the passphrase', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    await _type(tester, 'abc');

    // Deleting the ExcludeSemantics around the value display hands the typed
    // passphrase to every screen reader and accessibility service.
    expect(find.bySemanticsLabel(RegExp('abc')), findsNothing);
    expect(
      find.text('abc'),
      findsOneWidget,
      reason: 'it is on screen, just not in the semantics tree',
    );

    semantics.dispose();
  });
}

Future<void> _pump(
  WidgetTester tester, {
  GlobalKey<PassphraseInputState>? key,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      home: Scaffold(
        body: PassphraseInput(
          key: key,
          showLabel: 'Show',
          hideLabel: 'Hide',
          lettersLabel: 'ABC',
          symbolsLabel: '#+=',
          spaceLabel: 'Space',
        ),
      ),
    ),
  );
}

/// Types [value] the only way the widget accepts input: its own keyboard.
Future<void> _type(WidgetTester tester, String value) async {
  for (final character in value.characters) {
    await tester.tap(find.text(character));
  }
  await tester.pump();
}
