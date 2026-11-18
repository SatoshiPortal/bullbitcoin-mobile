import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/wallet/public/payment_destination.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_sdk/bull_sdk.dart' show BullSdk;
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(BullSdk.init);
  tearDownAll(BullSdk.dispose);
  const address = 'bcrt1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3lgth6c';
  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('pasting valid regtest displays a card in ${theme.name}', (
      tester,
    ) async {
      var changed = '';
      PaymentDestination? validated;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.getData' ? {'text': address} : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(theme),
          localizationsDelegates: [
            ...appLocalizationsDelegates,
            bullUiLocalizationsDelegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PaymentDestinationField(
              value: '',
              label: 'To',
              hint: 'Destination',
              acceptedTypes: const {PaymentDestinationType.bitcoin},
              onChanged: (value) => changed = value,
              onValidated: (value) => validated = value,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      expect(changed, address);
      expect(validated, isNotNull);
      expect(validated?.address, address);
      expect(validated?.type, PaymentDestinationType.bitcoin);
      expect(find.byType(AddressViewer), findsOneWidget);
      expect(find.text('Enter or scan a valid Bitcoin address.'), findsNothing);
      expect(find.text('Paste'), findsNothing);
    });
  }
  testWidgets('changing regtest policy revalidates the unchanged value', (
    tester,
  ) async {
    PaymentDestination? validated;
    Widget app(bool allowRegtest) => MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: [
        ...appLocalizationsDelegates,
        bullUiLocalizationsDelegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PaymentDestinationField(
          value: address,
          hint: 'Destination',
          acceptedTypes: const {PaymentDestinationType.bitcoin},
          allowRegtest: allowRegtest,
          onChanged: (_) {},
          onValidated: (value) => validated = value,
        ),
      ),
    );
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(validated?.address, address);
    expect(find.byType(AddressViewer), findsOneWidget);
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    expect(validated, isNull);
    expect(find.byType(AddressViewer), findsNothing);
    expect(find.text('Enter or scan a valid Bitcoin address.'), findsOneWidget);
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(validated?.address, address);
    expect(find.byType(AddressViewer), findsOneWidget);
  });
}
