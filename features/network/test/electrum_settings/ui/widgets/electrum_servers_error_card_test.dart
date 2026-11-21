import '../../../fixtures.dart';

import 'package:electrum/electrum.dart';
import 'package:network/src/electrum_settings/ui/widgets/electrum_servers_error_card.dart';
import 'package:network/src/tor_settings/ui/tor_settings_router.dart';
import 'package:network/generated/l10n/network_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('offers Tor settings for a configured Tor failure', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: ElectrumServersErrorCard(
              failure: ElectrumServersExternalTorProxyUnavailableFailure(),
            ),
          ),
        ),
        GoRoute(
          name: TorSettingsRoute.torSettings.name,
          path: '/tor-settings',
          builder: (context, state) => const Text('Tor settings destination'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: networkTestTheme(),
        localizationsDelegates: networkTestLocalizationsDelegates,
        supportedLocales: NetworkLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Tor settings'));
    await tester.pumpAndSettle();

    expect(find.text('Tor settings destination'), findsOneWidget);
  });
}
