import 'package:address_view/routes.dart' show AddressViewLocalizations;
import 'package:bull_ui/app_theme.dart';
import 'package:address_view/address_view.dart';
import 'package:address_view/payment_destination.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) pushed = route;
  }
}

void main() {
  const address = '1BoatSLRHtKNngkdXEeobR76b53LETtpyT';
  const uri = 'bitcoin:$address?amount=0.00002500';

  setUpAll(BullSdk.init);
  tearDownAll(BullSdk.dispose);

  Widget app({
    required Set<PaymentDestinationType> acceptedTypes,
    required ValueChanged<String> onChanged,
    ValueChanged<PaymentDestination?>? onValidated,
    NavigatorObserver? observer,
  }) => MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: [
      ...appLocalizationsDelegates,
      AddressViewLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    navigatorObservers: [?observer],
    home: Scaffold(
      body: PaymentDestinationField(
        value: '',
        hint: 'Destination',
        acceptedTypes: acceptedTypes,
        onChanged: onChanged,
        onValidated: onValidated,
      ),
    ),
  );

  testWidgets('pasted invalid input remains editable', (tester) async {
    var changed = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': 'bitcoin:'} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      app(
        acceptedTypes: {PaymentDestinationType.bitcoin},
        onChanged: (value) => changed = value,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(changed, 'bitcoin:');
    expect(find.text('Enter or scan a valid Bitcoin address.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'bitcoin:changed');
    expect(changed, 'bitcoin:', reason: 'typing is checked when left');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(changed, 'bitcoin:changed');
  });

  testWidgets('scanned Bitcoin is refused by a Lightning-only field', (
    tester,
  ) async {
    final observer = _RouteObserver();
    var changed = '';
    await tester.pumpWidget(
      app(
        acceptedTypes: {PaymentDestinationType.lightningAddress},
        onChanged: (value) => changed = value,
        observer: observer,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Scan'));
    final route = observer.pushed as MaterialPageRoute<void>;
    final scanner = route.builder(
      tester.element(find.byType(PaymentDestinationField)),
    ) as FullScreenScannerPage;
    scanner.onScannedPaymentRequest(address);
    route.navigator?.pop();
    await tester.pumpAndSettle();
    expect(changed, address);
    expect(
      find.text('Enter or scan a valid Lightning address.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('scanned BIP21 keeps its full URI and amount', (tester) async {
    final observer = _RouteObserver();
    var changed = '';
    PaymentDestination? validated;
    await tester.pumpWidget(
      app(
        acceptedTypes: {PaymentDestinationType.bitcoin},
        onChanged: (value) => changed = value,
        onValidated: (value) => validated = value,
        observer: observer,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Scan'));
    final route = observer.pushed as MaterialPageRoute<void>;
    final scanner = route.builder(
      tester.element(find.byType(PaymentDestinationField)),
    ) as FullScreenScannerPage;
    scanner.onScannedPaymentRequest(uri);
    route.navigator?.pop();
    await tester.pumpAndSettle();
    expect(changed, uri);
    expect(validated?.raw, uri);
    expect(validated?.address, address);
    expect(validated?.amountSat, 2500);
    expect(
      tester.widget<AddressViewer>(find.byType(AddressViewer)).clipboardText,
      uri,
    );
    expect(
      find.text('Bitcoin address · 2,500 sats from the QR'),
      findsOneWidget,
    );
  });
}
