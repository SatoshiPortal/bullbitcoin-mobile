import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:label_editor/label_editor.dart';
import 'package:label_editor/setup.dart';
import 'package:labels/labels.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Labels extends Mock implements Labels {}

void main() {
  testWidgets('the shared annotation field keeps its name while editing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const title = 'Transaction note';
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => LabelEditor.label(context, title: title),
              child: const Text('Open'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [
          LabelEditorLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: LabelEditorLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final editor = find.byType(EditableText);
    for (final value in ['', 'Payment received']) {
      if (value.isNotEmpty) {
        await tester.enterText(editor, value);
        await tester.pump();
      }
      final data = tester.getSemantics(editor).getSemanticsData();
      expect(data.label, title);
      expect(data.value, value);
      expect(data.flagsCollection.isTextField, isTrue);
    }
    semantics.dispose();
  });

  testWidgets('opens the mounted labels route and resolves labels lazily', (
    tester,
  ) async {
    var lookups = 0;
    final labels = _Labels();
    final editor = LabelEditorFeature.mount(
      labels: () {
        lookups++;
        return labels;
      },
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => LabelEditor.open(context),
              child: const Text('Open'),
            ),
          ),
        ),
        ...editor.routes,
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [
          LabelEditorLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: LabelEditorLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    expect(lookups, 0);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(router.namedLocation('labels'), '/labels');
    expect(find.text('BIP329 Labels Import/Export'), findsOneWidget);
    expect(lookups, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
