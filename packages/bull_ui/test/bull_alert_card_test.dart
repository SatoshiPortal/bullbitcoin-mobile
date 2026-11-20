import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required String title,
    String? body,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      wrapWithTheme(BullAlertCard(title: title, body: body, onTap: onTap)),
    );
  }

  testWidgets('renders the given title', (tester) async {
    await pumpCard(tester, title: 'Consolidate the wallet');

    expect(find.text('Consolidate the wallet'), findsOneWidget);
  });

  testWidgets('renders the body when provided', (tester) async {
    await pumpCard(
      tester,
      title: 'Consolidate the wallet',
      body: 'Something went wrong',
    );

    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('renders no body text when body is null', (tester) async {
    await pumpCard(tester, title: 'Consolidate the wallet');

    expect(find.text('Something went wrong'), findsNothing);
  });

  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;
    await pumpCard(
      tester,
      title: 'Consolidate the wallet',
      onTap: () => tapped = true,
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('the alert action has a name and a 48 dp target', (tester) async {
    await pumpCard(tester, title: 'Consolidate the wallet', onTap: () {});

    expect(
      tester.getSize(find.byType(InkWell)).shortestSide,
      greaterThanOrEqualTo(48),
    );
    expect(
      find.bySemanticsLabel(RegExp('Consolidate the wallet')),
      findsWidgets,
    );
  });

  testWidgets('a card without a callback is static', (tester) async {
    await pumpCard(tester, title: 'Consolidate the wallet');

    expect(find.byType(InkWell), findsNothing);
  });
}
