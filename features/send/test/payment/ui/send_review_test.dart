// Keep new Send tests independent of the application package namespace.
// ignore: avoid_relative_lib_imports
import 'package:send/send.dart';

import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'review preserves recipient order with only note edit and confirmation',
    (tester) async {
      var notes = 0;
      var confirms = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: testBullExtensions,
            textTheme: testBullTypography.toTextTheme(),
          ),
          home: SendPaymentReview(
            title: 'Send',
            stepLabels: const ['Amount', 'Recipients', 'Confirm'],
            stepSemanticLabel: (i, text) => text,
            youSendLabel: 'You send',
            amount: const Text('50,000 sats'),
            equivalent: '≈ 50 CAD',
            recipients: const [Text('External destination'), Text('My wallet')],
            fromLabel: 'From',
            source: const Text('bitcoin'),
            editLabel: 'Edit note',
            noteLabel: 'Note',
            note: 'Add note',
            feeLabel: 'Network fee',
            fee: const Text('200 sats'),
            feeDetail: 'Fast · 2 sat/vB',
            totalLabel: 'Total debited',
            total: const Text('50,200 sats'),
            confirmLabel: 'Confirm payment',
            onBack: () {},
            onNote: () => notes++,
            onConfirm: () => confirms++,
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('You send')).textAlign,
        TextAlign.center,
      );
      expect(
        tester.getTopLeft(find.text('From')).dx,
        tester.getTopLeft(find.text('Note')).dx,
      );
      expect(
        tester.getBottomRight(find.text('bitcoin')).dx,
        closeTo(tester.getBottomRight(find.text('200 sats')).dx, 1),
      );
      expect(tester.getTopLeft(find.text('From')).dx, 16);
      expect(
        tester.getTopLeft(find.text('You send')).dy -
            tester.getBottomLeft(find.byType(BullStepBar)).dy,
        greaterThanOrEqualTo(24),
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(BullSegmented), findsNothing);
      expect(find.byType(BullSettingsEntryTile), findsNothing);
      expect(
        tester.getTopLeft(find.text('External destination')).dy,
        lessThan(tester.getTopLeft(find.text('My wallet')).dy),
      );
      await tester.ensureVisible(find.text('Add note'));
      await tester.tap(find.text('Add note'));
      expect(notes, 1);
      await tester.tap(find.text('Confirm payment'));
      expect(confirms, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
