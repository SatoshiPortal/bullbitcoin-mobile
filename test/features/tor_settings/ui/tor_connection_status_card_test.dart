import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_connection_status_card.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_tor/tor.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, TorConnectionState state) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TorConnectionStatusCard(connection: state)),
      ),
    );
    await tester.pump();
  }

  testWidgets('explains a filtered network while Tor is still trying', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const TorConnecting(
        source: TorSource.embedded,
        progress: 0.2,
        diagnostic: TorDiagnostic.filtering,
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.torSettingsStatusCensored), findsOneWidget);
    expect(find.text(l10n.torSettingsDescCensored), findsOneWidget);
  });

  // The case that matters: in `direct` mode nothing falls back to Snowflake, so
  // this failure is the only place the user can learn that the network — not
  // the app — is the problem.
  testWidgets('keeps explaining it after the bootstrap gave up', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const TorUnavailable(
        source: TorSource.embedded,
        failure: TorBootstrapFailure('filtered', TorDiagnostic.filtering),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.torSettingsStatusCensored), findsOneWidget);
    expect(find.text(l10n.torSettingsDescCensored), findsOneWidget);
  });

  testWidgets('does not claim filtering for an unexplained failure', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const TorUnavailable(
        source: TorSource.embedded,
        failure: TorBootstrapFailure('no directory'),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.torSettingsStatusCensored), findsNothing);
    expect(find.text(l10n.torSettingsStatusDisconnected), findsOneWidget);
  });

  testWidgets('shows what arti says while Tor is stuck', (tester) async {
    await pumpCard(
      tester,
      const TorConnecting(
        source: TorSource.embedded,
        progress: 0.4,
        diagnostic: TorDiagnostic.cantBootstrap,
        detail: TorBootstrapDetail(blockage: "Can't make progress."),
      ),
    );

    expect(find.text("Can't make progress."), findsOneWidget);
  });

  testWidgets('keeps showing it once the bootstrap gave up', (tester) async {
    await pumpCard(
      tester,
      const TorUnavailable(
        source: TorSource.embedded,
        failure: TorBootstrapFailure(
          'bootstrap failed',
          TorDiagnostic.cantBootstrap,
          TorBootstrapDetail(blockage: "Can't make progress."),
        ),
      ),
    );

    expect(find.text("Can't make progress."), findsOneWidget);
  });

  testWidgets('shows the active transport when one is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TorConnectionStatusCard(
            connection: TorReady(
              TorRoute(
                source: TorSource.embedded,
                endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
                evidence: TorReadinessEvidence.embeddedBootstrap,
                transport: TorTransport.snowflake,
              ),
            ),
            routeLabel: 'Active transport: Snowflake',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Active transport: Snowflake'), findsOneWidget);
  });

  testWidgets('tells the user the device is offline', (tester) async {
    await pumpCard(
      tester,
      const TorConnecting(
        source: TorSource.embedded,
        progress: 0.1,
        diagnostic: TorDiagnostic.offline,
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.torSettingsStatusOffline), findsOneWidget);
    expect(find.text(l10n.torSettingsDescOffline), findsOneWidget);
  });

  testWidgets('asks to fix the clock and shows the measured skew', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const TorUnavailable(
        source: TorSource.embedded,
        failure: TorBootstrapFailure(
          'skewed',
          TorDiagnostic.clockSkewed,
          TorBootstrapDetail(blockage: 'Clock is skewed by 2 hours'),
        ),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.torSettingsStatusClockSkewed), findsOneWidget);
    expect(find.text(l10n.torSettingsDescClockSkewed), findsOneWidget);
    expect(find.text('Clock is skewed by 2 hours'), findsOneWidget);
  });

  testWidgets('offers retry and Snowflake when Tor cannot bootstrap', (
    tester,
  ) async {
    var retries = 0;
    var snowflake = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TorConnectionStatusCard(
            connection: const TorConnecting(
              source: TorSource.embedded,
              progress: 0.5,
              diagnostic: TorDiagnostic.cantBootstrap,
            ),
            onRetry: () => retries++,
            onUseSnowflake: () => snowflake++,
          ),
        ),
      ),
    );
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.torSettingsStatusCantBootstrap), findsOneWidget);
    await tester.tap(find.text(l10n.torSettingsRetry));
    await tester.tap(find.text(l10n.torSettingsUseSnowflake));
    expect((retries, snowflake), (1, 1));
  });

  testWidgets('offers no Snowflake switch that has nowhere to go', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const TorConnecting(
        source: TorSource.embedded,
        progress: 0.5,
        diagnostic: TorDiagnostic.cantBootstrap,
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.torSettingsUseSnowflake), findsNothing);
  });
}
