import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_proxy_widget.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTorSettingsCubit extends Mock implements TorSettingsCubit {}

void main() {
  Future<void> pumpWidgetWithState(
    WidgetTester tester,
    TorSettingsState state,
  ) async {
    final cubit = _MockTorSettingsCubit();
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<TorSettingsCubit>.value(
            value: cubit,
            child: const SingleChildScrollView(child: TorProxyWidget()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'shows only the reachable external proxy when it is selected',
    (tester) async {
      final state = TorSettingsState(
        useTorProxy: true,
        connection: TorReady(
          TorRoute(
            source: TorSource.external,
            endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 9050),
            evidence: TorReadinessEvidence.externalSocksHandshake,
          ),
        ),
      );
      await pumpWidgetWithState(tester, state);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.torSettingsConnectionStatus), findsOneWidget);
      expect(find.text(l10n.torSettingsStatusUnknown), findsNothing);
      expect(find.text(l10n.torSettingsStatusConnected), findsNothing);
      expect(find.text('Proxy reachable'), findsOneWidget);
      expect(
        find.text('The configured SOCKS5 proxy accepted a connection.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('keeps the embedded status when the external proxy is disabled', (
    tester,
  ) async {
    final state = TorSettingsState(
      embeddedConnection: TorReady(
        TorRoute(
          source: TorSource.embedded,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
          evidence: TorReadinessEvidence.embeddedBootstrap,
          transport: TorTransport.direct,
        ),
      ),
    );
    await pumpWidgetWithState(tester, state);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.torSettingsConnectionStatus), findsOneWidget);
    expect(find.text(l10n.torSettingsStatusConnected), findsOneWidget);
    expect(find.text('Proxy reachable'), findsNothing);
  });
}
