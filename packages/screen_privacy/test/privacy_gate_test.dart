import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_privacy/screen_privacy.dart';

void main() {
  Widget app(Future<void> protection) => MaterialApp(
    home: PrivacyGate(
      protection: protection,
      unprotected: const Text('unprotected'),
      builder: (_) => const Text('secret'),
    ),
  );

  testWidgets('shows nothing secret until protection completes', (
    tester,
  ) async {
    final protection = Completer<void>();
    await tester.pumpWidget(app(protection.future));

    expect(find.text('secret'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    protection.complete();
    await tester.pump();

    expect(find.text('secret'), findsOneWidget);
  });

  testWidgets('never builds the secret when protection fails', (tester) async {
    final protection = Completer<void>();
    await tester.pumpWidget(app(protection.future));

    protection.completeError(const ScreenCaptureProtectionException());
    await tester.pump();

    expect(find.text('secret'), findsNothing);
    expect(find.text('unprotected'), findsOneWidget);
  });
}
