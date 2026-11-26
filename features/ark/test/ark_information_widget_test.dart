import 'package:ark/ark.dart';
import 'package:bull_ark/generated/l10n/ark_localizations.dart';
import 'package:bull_ark/src/ui/ark_connection_details.dart';
import 'package:bull_ark/src/ui/ark_information_screen.dart';
import 'package:bull_ui/testing.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullDetailsTable,
        BullDetailsTableItem,
        BullAmountScope,
        BullAmountSnapshot,
        bullUiLocalizationsDelegate;
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

Widget app(
  Widget child, {
  String language = 'en',
  BullAmountSnapshot? amountPreferences = const BullAmountSnapshot(
    unit: BitcoinUnit.sats,
    hideAmounts: false,
    isReady: true,
  ),
}) => MaterialApp(
  locale: Locale(language),
  supportedLocales: ArkLocalizations.supportedLocales,
  localizationsDelegates: const [
    ArkLocalizations.delegate,
    bullUiLocalizationsDelegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  theme: ThemeData(extensions: testBullExtensions),
  // Above the navigator, as in the app, so pushed pages share the scope.
  builder: amountPreferences == null
      ? null
      : (context, navigator) => BullAmountScope(
          snapshot: amountPreferences,
          writeUnit: (_) async => false,
          child: navigator ?? const SizedBox.shrink(),
        ),
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
    expect(details(tester), containsPair('Ark server', 'ark.example.com'));
    expect(details(tester), containsPair('Server public key', 'public…er-key'));
    expect(
      tester
          .widgetList<BullDetailsTableItem>(find.byType(BullDetailsTableItem))
          .firstWhere((row) => row.label == 'Server public key')
          .copyValue,
      'public-server-key',
    );
    expect(details(tester), containsPair('Minimum board amount', '1,200 sats'));
    expect(
      details(tester),
      containsPair('Maximum VTXO amount', '800,000 sats'),
    );
    expect(details(tester), containsPair('Required confirmations', '3'));
    expect(details(tester), containsPair('Round interval', '10 sec'));
    expect(
      details(tester),
      containsPair('VTXO lifetime', '4,320 blocks (~30 days)'),
    );
    expect(
      details(tester),
      containsPair('Auto-renew before expiry', '1,008 blocks (~7 days)'),
    );
    expect(
      details(tester),
      containsPair('Primary Esplora', 'esplora.nodl.example.com'),
    );
    expect(find.textContaining('without Tor'), findsOneWidget);
    expect(details(tester).keys.take(3), [
      'Ark server',
      'Primary Esplora',
      'Unreachable-only fallback',
    ]);
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
      containsPair('Montant minimum de dépôt', 'Indisponible'),
    );
    expect(
      details(tester),
      containsPair('Intervalle des rounds', 'Indisponible'),
    );
    expect(
      details(tester),
      containsPair('Montant maximum d’un VTXO', 'Indisponible'),
    );
    expect(find.textContaining('Dernières données observées.'), findsNothing);
    expect(find.textContaining('sans Tor'), findsOneWidget);
  });

  for (final (language, label, value) in [
    ('en', 'Maximum VTXO amount', 'No limit'),
    ('fr', 'Montant maximum d’un VTXO', 'Aucune limite'),
  ]) {
    testWidgets('a server without a VTXO maximum shows no limit ($language)', (
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
        ),
      );
      await tester.pumpWidget(
        app(
          ArkInformationScreen(snapshot: observed, config: config()),
          language: language,
        ),
      );
      await tester.pumpAndSettle();
      expect(details(tester), containsPair(label, value));
    });
  }
}
