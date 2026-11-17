import 'package:btc_map/src/map_types.dart';
import 'package:bull_ui/testing.dart';
import 'package:btc_map/src/ui/widgets/merchant_details_sheet.dart';
import 'package:btc_map/generated/l10n/btc_map_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, Merchant merchant) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(extensions: testBullExtensions),
    locale: const Locale('en'),
    localizationsDelegates: BtcMapLocalizations.localizationsDelegates,
    supportedLocales: BtcMapLocalizations.supportedLocales,
    home: Scaffold(body: MerchantDetailsSheet(merchant: merchant)),
  ),
);

void main() {
  final location = GeoPoint(latitude: 45.5, longitude: -73.6);

  testWidgets('a recently verified place shows the verified badge', (
    tester,
  ) async {
    final today = DateTime.now();
    await _pump(
      tester,
      Merchant(
        id: 1,
        location: location,
        name: 'Shop',
        verifiedAt: DateTime.utc(today.year, today.month, today.day),
      ),
    );
    expect(
      find.byKey(const ValueKey('merchant-verification-recent')),
      findsOne,
    );
    expect(find.byIcon(Icons.verified), findsOne);
  });

  testWidgets('a stale or never verified place shows the attention badge', (
    tester,
  ) async {
    await _pump(
      tester,
      Merchant(id: 1, location: location, verifiedAt: DateTime.utc(2020, 3, 4)),
    );
    expect(
      find.byKey(const ValueKey('merchant-verification-outdated')),
      findsOne,
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOne);
    expect(find.textContaining('Mar 4, 2020'), findsOne);

    await _pump(tester, Merchant(id: 1, location: location));
    expect(find.byKey(const ValueKey('merchant-verification-never')), findsOne);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOne);
  });

  testWidgets('shows payment methods, email and social links', (tester) async {
    await _pump(
      tester,
      Merchant(
        id: 1,
        location: location,
        email: 'shop@example.com',
        socialLinks: [Uri.parse('https://www.instagram.com/shop')],
        paymentMethods: const {
          MerchantPaymentMethod.lightning,
          MerchantPaymentMethod.onchain,
        },
      ),
    );
    expect(find.text('On-chain · Lightning'), findsOne);
    expect(find.text('shop@example.com'), findsOne);
    expect(find.text('instagram.com'), findsOne);
  });
}
