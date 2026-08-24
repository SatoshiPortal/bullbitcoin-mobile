import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_settings_failure.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/electrum_servers_error_card.dart';
import 'package:bb_mobile/features/tor_settings/ui/tor_settings_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
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
              failure: ElectrumServersConfiguredExternalTorUnavailableFailure(),
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
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Tor settings'));
    await tester.pumpAndSettle();

    expect(find.text('Tor settings destination'), findsOneWidget);
  });
}
