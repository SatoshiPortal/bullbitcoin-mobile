import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show MaterialApp, MediaQueryData;

void main() {
  for (final network in BullPaymentNetwork.values) {
    for (final phase in BullPaymentPhase.values) {
      testWidgets('$network $phase paints a static reduced-motion pose', (
        tester,
      ) async {
        var done = 0;
        var impacts = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: BullPaymentAnimation(
                network: network,
                phase: phase,
                onDone: () => done++,
                onImpact: () => impacts++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final terminal =
            phase == BullPaymentPhase.success ||
            phase == BullPaymentPhase.failed;
        expect(done, terminal ? 1 : 0);
        expect(impacts, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('pending transition offers a named skip without settling', (
    tester,
  ) async {
    var skipped = 0;
    var backdropTaps = 0;
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.dark),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: BullPaymentTransition(
            network: BullPaymentNetwork.lightning,
            phase: BullPaymentPhase.sending,
            status: 'Payment pending',
            skipLabel: 'View details',
            onSkip: () => skipped++,
            onBackdropTap: () => backdropTaps++,
            onDone: () => done++,
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(100, 100));
    expect(backdropTaps, 1);
    expect(skipped, 0);
    await tester.tap(find.text('View details'));
    await tester.pump();
    expect(skipped, 1);
    expect(backdropTaps, 1);
    expect(done, 0);
  });

  testWidgets('fast completion keeps the intro then plays one terminal phase', (
    tester,
  ) async {
    var done = 0;
    Widget screen(BullPaymentPhase phase) => MaterialApp(
      theme: AppTheme.themeData(AppThemeType.dark),
      home: BullPaymentTransition(
        network: BullPaymentNetwork.bitcoin,
        phase: phase,
        status: phase == BullPaymentPhase.sending ? 'Sending' : 'Sent',
        skipLabel: 'View details',
        onSkip: null,
        onDone: () => done++,
      ),
    );

    await tester.pumpWidget(screen(BullPaymentPhase.sending));
    await tester.pump();
    await tester.pumpWidget(screen(BullPaymentPhase.success));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sending'), findsOneWidget);
    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Sent'), findsOneWidget);
    for (var frame = 0; frame < 50; frame++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(done, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(done, 1);
  });

  testWidgets('an inactive scene cannot finish in the background', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BullPaymentAnimation(
          network: BullPaymentNetwork.ark,
          phase: BullPaymentPhase.success,
          onDone: () => done++,
        ),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 3));
    expect(done, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(done, 1);
  });
}
