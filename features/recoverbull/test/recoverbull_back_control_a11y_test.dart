import 'package:bull_recoverbull/src/ui/widgets/recoverbull_widgets.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// The flow's back control must be reachable by name: a control the
/// accessibility tree cannot name leaves screen-reader users without the only
/// way out of a page, and agents and tests can only drive the app by name.
void main() {
  testWidgets('the flow app bar names its back control', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        home: const Scaffold(
          appBar: RecoverBullAppBar(
            title: 'Secure your backup',
            showKeyServer: false,
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(RecoverBullAppBar));
    final backTooltip = MaterialLocalizations.of(context).backButtonTooltip;
    expect(find.byTooltip(backTooltip), findsOneWidget);
  });
}
