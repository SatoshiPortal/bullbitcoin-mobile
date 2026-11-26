import 'package:access/access.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the veil covers on inactive and lifts on resume', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AccessPrivacyVeil(child: Text('wallet content'))),
    );
    final veil = find.byKey(const ValueKey('access-privacy-veil'));
    expect(veil, findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(veil, findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(veil, findsNothing);
  });
}
