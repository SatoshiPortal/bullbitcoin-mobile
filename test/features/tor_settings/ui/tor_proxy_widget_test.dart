import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_proxy_widget.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTorSettingsCubit extends Mock implements TorSettingsCubit {}

void main() {
  Future<_MockTorSettingsCubit> pumpWidgetWithState(
    WidgetTester tester,
    TorSettingsState state,
  ) async {
    final cubit = _MockTorSettingsCubit();
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.checkConnectionStatus()).thenAnswer((_) async {});
    when(
      () => cubit.updateTorSettings(
        useTorProxy: any(named: 'useTorProxy'),
        torProxyPort: any(named: 'torProxyPort'),
      ),
    ).thenAnswer((_) async {});

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
    return cubit;
  }

  testWidgets('shows only the reachable external proxy when it is selected', (
    tester,
  ) async {
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
    expect(find.text(l10n.torSettingsConnectionStatus), findsNothing);
    expect(find.text('Local SOCKS5 proxy status'), findsOneWidget);
    expect(find.text(l10n.torSettingsStatusUnknown), findsNothing);
    expect(find.text(l10n.torSettingsStatusConnected), findsNothing);
    expect(find.text(l10n.torSettingsEmbeddedTitle), findsNothing);
    expect(find.text(l10n.torSettingsTransportMode), findsNothing);
    expect(find.text('Local SOCKS5 proxy (advanced)'), findsOneWidget);
    expect(find.text(l10n.torSettingsExternalProxyReachable), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(
      find.text(l10n.torSettingsExternalProxyReachableDescription),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows only a failed replacement while keeping the active proxy',
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
        externalProxyAttempt: const TorUnavailable(
          source: TorSource.external,
          failure: TorExternalProxyUnavailableFailure(),
        ),
        externalProxyAttemptPort: 9051,
      );
      final cubit = await pumpWidgetWithState(tester, state);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.text(l10n.torSettingsExternalProxyUnavailable),
        findsOneWidget,
      );
      expect(find.text(l10n.torSettingsExternalProxyReachable), findsNothing);
      expect(
        find.text(l10n.torSettingsProxyAttemptWithActivePort(9051, 9050)),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      verify(
        () => cubit.updateTorSettings(useTorProxy: true, torProxyPort: 9051),
      ).called(1);
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
    expect(find.text(l10n.torSettingsExternalProxyReachable), findsNothing);
    expect(find.text(l10n.torSettingsEmbeddedTitle), findsOneWidget);
    expect(find.text(l10n.torSettingsTransportMode), findsOneWidget);
    expect(find.text(l10n.torSettingsPortDisplay(9050)), findsOneWidget);
  });

  testWidgets('retries an already selected external proxy', (tester) async {
    final cubit = await pumpWidgetWithState(
      tester,
      const TorSettingsState(useTorProxy: true),
    );

    await tester.tap(find.text('Retry'));
    verify(() => cubit.checkConnectionStatus()).called(1);
  });

  testWidgets('retries a failed external activation', (tester) async {
    final cubit = await pumpWidgetWithState(
      tester,
      const TorSettingsState(
        externalProxyAttempt: TorUnavailable(
          source: TorSource.external,
          failure: TorExternalProxyUnavailableFailure(),
        ),
        externalProxyAttemptPort: 9150,
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.torSettingsProxyAttemptPort(9150)), findsOneWidget);
    await tester.tap(find.text('Retry'));
    verify(
      () => cubit.updateTorSettings(useTorProxy: true, torProxyPort: 9150),
    ).called(1);
  });

  testWidgets('opens Orbot information without checking installed apps', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await pumpWidgetWithState(tester, const TorSettingsState());
    await tester.tap(find.text('Learn about Orbot'));
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'launch');
    expect((calls.single.arguments as Map)['url'], 'https://orbot.app/');
  });

  testWidgets('shows a local snackbar when the Orbot link cannot open', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await pumpWidgetWithState(tester, const TorSettingsState());
    await tester.tap(find.text('Learn about Orbot'));
    await tester.pump();

    expect(find.text('Unable to open the Orbot website.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
