import 'package:ark/ark.dart';
import 'package:bull_ark/generated/l10n/ark_localizations.dart';
import 'package:bull_ark/src/ui/ark_connection_details.dart';
import 'package:bull_ark/src/ui/ark_information_screen.dart';
import 'package:bull_ui/testing.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullDetailsTable, BullDetailsTableItem;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

import 'ark_operations_test.dart' show account;

ArkAccountConfig config({bool fallback = true}) => ArkAccountConfig(
  id: account(),
  arkUrl: Uri.parse('https://ark.example.com'),
  primaryEsploraUrl: Uri.parse('https://esplora.nodl.example.com'),
  fallbackEsploraUrl: fallback
      ? Uri.parse('https://blockstream.example.com/api')
      : null,
  renewalThresholdBlocks: 1008,
);

Widget app(Widget child, {String language = 'en'}) => MaterialApp(
  locale: Locale(language),
  supportedLocales: ArkLocalizations.supportedLocales,
  localizationsDelegates: const [
    ArkLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  theme: ThemeData(extensions: testBullExtensions),
  home: child,
);

Map<String, String?> details(WidgetTester tester) => {
  for (final table in tester.widgetList<BullDetailsTable>(
    find.byType(BullDetailsTable),
  ))
    for (final row in table.items.whereType<BullDetailsTableItem>())
      row.label: row.displayValue,
};

void main() {
  testWidgets(
    'connection details show the configured providers and threshold',
    (tester) async {
      await tester.pumpWidget(
        app(Scaffold(body: ArkConnectionDetails(config: config()))),
      );
      await tester.pumpAndSettle();
      expect(details(tester), {
        'Ark server': 'https://ark.example.com',
        'Primary Esplora': 'https://esplora.nodl.example.com',
        'Unreachable-only fallback': 'https://blockstream.example.com/api',
        'Renewal threshold (blocks)': '1008',
      });
    },
  );

  testWidgets('an absent fallback does not display an invented provider', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Scaffold(body: ArkConnectionDetails(config: config(fallback: false))),
      ),
    );
    await tester.pumpAndSettle();
    expect(details(tester), hasLength(3));
    expect(details(tester), isNot(contains('Unreachable-only fallback')));
  });

  testWidgets('server limits retain their amounts and explicit units', (
    tester,
  ) async {
    final observed = ArkSnapshot(
      account: account(),
      revision: 2,
      observedAt: DateTime.utc(2026),
      stale: false,
      serverInfo: ArkServerInfo(
        publicKey: 'public-server-key',
        minimumBoard: Sats.fromInt(1200),
        maximumVtxo: Sats.fromInt(800000),
        boardConfirmations: 3,
        roundIntervalSeconds: 10,
        vtxoLifetimeBlocks: 4320,
      ),
    );
    await tester.pumpWidget(
      app(ArkInformationScreen(snapshot: observed, config: config())),
    );
    await tester.pumpAndSettle();
    expect(
      details(tester),
      containsPair('Public server key', 'public-server-key'),
    );
    expect(
      details(tester),
      containsPair('Minimum boarding amount (sats)', '1200'),
    );
    expect(
      details(tester),
      containsPair('Maximum VTXO amount (sats)', '800000'),
    );
    expect(details(tester), containsPair('Board confirmations', '3'));
    expect(details(tester), containsPair('Round interval (seconds)', '10'));
    expect(details(tester), containsPair('VTXO lifetime (blocks)', '4320'));
    expect(find.textContaining('without Tor'), findsOneWidget);
  });

  testWidgets('missing observed limits remain unavailable in French', (
    tester,
  ) async {
    final observed = ArkSnapshot(
      account: account(),
      revision: 2,
      observedAt: DateTime.utc(2026),
    );
    await tester.pumpWidget(
      app(
        ArkInformationScreen(snapshot: observed, config: config()),
        language: 'fr',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      details(tester),
      containsPair('Clé publique du serveur', 'Indisponible'),
    );
    expect(
      details(tester),
      containsPair('Montant minimum de dépôt (sats)', 'Indisponible'),
    );
    expect(
      details(tester),
      containsPair('Intervalle des rounds (secondes)', 'Indisponible'),
    );
    expect(find.textContaining('Dernières données observées.'), findsOneWidget);
    expect(find.textContaining('sans Tor'), findsOneWidget);
  });
}
