import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders caller copy without optional actions', (tester) async {
    const labels = (
      from: 'Origin',
      to: 'Destination',
      selfTransfer: 'Internal transfer',
      payjoin: 'Collaborative payment',
      note: 'Message',
      amount: 'Value',
      networkFee: 'Network cost',
      feePriority: 'Confirmation speed',
    );
    await tester.pumpWidget(
      wrapWithTheme(
        BullOnchainSendInfoSection(
          labels: labels,
          sendWalletLabel: 'Savings',
          addressBuilder: (style, color) =>
              BullText('Recipient', style: style.copyWith(color: color)),
          formattedBitcoinAmount: '25,000 sats',
          formattedFiatEquivalent: '25 CAD',
          absoluteFees: '200 sats',
          selectedFeeOptionTitle: 'Fast',
          isToSelf: true,
          note: 'Invoice 42',
        ),
      ),
    );

    for (final text in [
      labels.from,
      labels.to,
      labels.selfTransfer,
      labels.note,
      labels.amount,
      labels.networkFee,
      'Savings',
      'Recipient',
      '25,000 sats',
      '25 CAD',
      '200 sats',
      'Invoice 42',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.text(labels.feePriority), findsNothing);
    expect(find.text(labels.payjoin), findsNothing);
    expect(find.byType(BullSwitch), findsNothing);
  });
}
