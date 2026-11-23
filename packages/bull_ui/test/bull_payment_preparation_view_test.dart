import 'package:bull_ui/testing.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final theme in [Brightness.light, Brightness.dark]) {
    testWidgets('payment preparation and failure in ${theme.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final error = ValueNotifier<String?>(null);
      final canLeave = ValueNotifier<bool>(false);
      addTearDown(error.dispose);
      addTearDown(canLeave.dispose);
      var backCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: theme, extensions: testBullExtensions),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ValueListenableBuilder(
                      valueListenable: canLeave,
                      builder: (_, canPop, _) => PopScope(
                        canPop: canPop,
                        child: ValueListenableBuilder(
                          valueListenable: error,
                          builder: (_, message, _) =>
                              BullPaymentPreparationView(
                                title: 'Payment destination',
                                detailLabels: const [
                                  'Payment amount',
                                  'Destination',
                                  'Order number',
                                ],
                                errorMessage: message,
                                onBack: () => backCalls++,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open payment'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open payment'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(BullDetailsTableItem), findsNWidgets(3));
      expect(find.byType(BullShimmerLine), findsNWidgets(3));
      final back = find.byType(BackButton);
      expect(back, findsOneWidget);

      await tester.tap(back);
      await tester.pump();
      expect(backCalls, 0);
      expect(find.byType(BullPaymentPreparationView), findsOneWidget);

      error.value = '';
      await tester.pump();
      expect(find.byType(BullDetailsTableItem), findsNothing);

      error.value = 'Payment details are unavailable';
      await tester.pump();
      expect(find.text(error.value!), findsOneWidget);
      expect(backCalls, 0);

      canLeave.value = true;
      await tester.pump();
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(backCalls, 1);
      expect(find.text('Open payment'), findsOneWidget);
    });
  }
}
