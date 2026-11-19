import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/ui/ark_information_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ark_information_widget_test.dart' show app, config, details;
import 'ark_operations_test.dart' show account;

void main() {
  ArkSnapshot observed({bool stale = false, bool cached = true}) => ArkSnapshot(
    account: account(),
    revision: 2,
    observedAt: DateTime.utc(2026),
    stale: stale,
    serverInfo: cached
        ? const ArkServerInfo(publicKey: 'real-public-server-key')
        : null,
  );

  testWidgets('fresh snapshot without connection evidence remains unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(ArkInformationScreen(snapshot: observed(), config: config())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Online'), findsNothing);
    expect(find.text('Offline'), findsNothing);
    expect(details(tester), containsPair('ark.example.com', 'Unavailable'));
  });

  testWidgets(
    'explicit scoped offline retains cached facts without fabricated age',
    (tester) async {
      await tester.pumpWidget(
        app(
          ArkInformationScreen(
            snapshot: observed(stale: true),
            config: config(),
            serverConnection: (account(), config().arkUrl, false),
            serverExitDelta: (account(), config().arkUrl, 72),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      expect(
        details(tester),
        containsPair('Server public key', 'real-public-server-key'),
      );
      expect(details(tester), containsPair('VTXO exit delta', '72 blocks'));
      expect(find.textContaining('12 minutes'), findsNothing);
    },
  );

  testWidgets('foreign server observations cannot set status or exit delta', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ArkInformationScreen(
          snapshot: observed(),
          config: config(),
          serverConnection: (
            account(),
            Uri.parse('https://foreign.example'),
            true,
          ),
          serverExitDelta: (
            account(),
            Uri.parse('https://foreign.example'),
            72,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Online'), findsNothing);
    expect(details(tester), containsPair('VTXO exit delta', 'Unavailable'));
  });

  testWidgets(
    'uncached loading and explicit error expose honest retry states',
    (tester) async {
      await tester.pumpWidget(
        app(
          ArkInformationScreen(
            snapshot: observed(cached: false),
            config: config(),
            loading: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Loading Ark…'), findsOneWidget);
      expect(find.text('Keys'), findsNothing);
      var retries = 0;
      await tester.pumpWidget(
        app(
          ArkInformationScreen(
            snapshot: observed(cached: false),
            config: config(),
            failure: const ArkServiceUnavailableFailure(),
            onRetry: () => retries++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Can’t reach the Ark server'), findsNothing);
      expect(find.text('Ark is unavailable. Try again.'), findsWidgets);
      tester
          .widget<BullButton>(find.widgetWithText(BullButton, 'Retry'))
          .onPressed();
      expect(retries, 1);
    },
  );
  testWidgets('null snapshot shows loading without an invented observation', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ArkInformationScreen(snapshot: null, config: config(), loading: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Loading Ark…'), findsOneWidget);
    expect(find.text('Keys'), findsNothing);
    expect(find.byType(BullQrCode), findsNothing);
    expect(find.byType(BullDetailsTable), findsNothing);
    expect(find.text('Online'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'null snapshot exposes explicit error and real retry capability',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        app(
          ArkInformationScreen(
            snapshot: null,
            config: config(),
            failure: const ArkServiceUnavailableFailure(),
            onRetry: () => retries++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ark is unavailable. Try again.'), findsWidgets);
      expect(find.text('Can’t reach the Ark server'), findsNothing);
      expect(find.byType(BullDetailsTable), findsNothing);
      expect(find.byType(BullQrCode), findsNothing);
      tester
          .widget<BullButton>(find.widgetWithText(BullButton, 'Retry'))
          .onPressed();
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'null snapshot without lifecycle evidence leaves observations unavailable',
    (tester) async {
      await tester.pumpWidget(
        app(ArkInformationScreen(snapshot: null, config: config())),
      );
      await tester.pumpAndSettle();
      expect(details(tester), containsPair('Server public key', 'Unavailable'));
      expect(find.text('Online'), findsNothing);
      expect(find.text('Offline'), findsNothing);
      expect(find.byType(BullQrCode), findsNothing);
      expect(find.widgetWithText(BullButton, 'Retry'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
