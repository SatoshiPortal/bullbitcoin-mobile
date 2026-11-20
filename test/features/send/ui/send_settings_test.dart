// ignore: avoid_relative_lib_imports
import '../../../../lib/features/send/ui/widgets/send_payment_settings.dart';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget settings({ValueChanged<bool>? onRbf, double scale = 1}) => MaterialApp(
    theme: ThemeData(
      extensions: testBullExtensions,
      textTheme: testBullTypography.toTextTheme(),
    ),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: SendPaymentSettings(
          title: 'Advanced settings',
          closeLabel: 'Close',
          feeLabel: 'Network fee',
          feeChoices: const {
            FeeSelection.fastest: 'Fast',
            FeeSelection.economic: 'Economy',
            FeeSelection.custom: 'Custom',
          },
          selectedFee: FeeSelection.fastest,
          feeDetail: const Text('140 sats'),
          editLabel: 'Edit',
          rbfLabel: 'Replace by fee',
          replaceByFee: false,
          multipleLabel: 'Multiple recipients',
          multipleRecipients: false,
          coinsLabel: 'Send UTXOs instead',
          onClose: () {},
          onFeeSelected: (_) {},
          onReplaceByFee: onRbf,
          onMultipleRecipients: null,
          onCoins: () {},
        ),
      ),
    ),
  );

  testWidgets('row label and switch each toggle exactly once', (tester) async {
    final values = <bool>[];
    await tester.pumpWidget(settings(onRbf: values.add));
    expect(
      tester.getTopLeft(find.text('Send UTXOs instead')).dx,
      tester.getTopLeft(find.text('Replace by fee')).dx,
    );
    expect(
      tester.getBottomRight(find.byType(BullIcon).last).dx,
      tester.getBottomRight(find.byType(BullSwitch).last).dx,
    );
    await tester.tap(find.text('Replace by fee'));
    expect(values, [true]);
    await tester.tap(find.byType(BullSwitch).first);
    expect(values, [true, true]);
    await tester.tap(find.text('Multiple recipients'));
    expect(values, [true, true]);
  });

  testWidgets('small sheet scrolls and long labels do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(settings(scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Send UTXOs instead'));
    expect(tester.takeException(), isNull);
  });
}
