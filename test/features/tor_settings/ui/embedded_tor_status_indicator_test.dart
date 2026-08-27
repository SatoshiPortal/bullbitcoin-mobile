import 'dart:ui' show SemanticsAction;

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/embedded_tor_status_cubit.dart';
import 'package:bb_mobile/features/tor_settings/ui/tor_settings_router.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/embedded_tor_status_indicator.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockEmbeddedTorStatusCubit extends Mock
    implements EmbeddedTorStatusCubit {}

void main() {
  Future<_MockEmbeddedTorStatusCubit> pumpIndicator(
    WidgetTester tester,
    EmbeddedTorStatusState state, {
    Size size = const Size(400, 800),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final cubit = _MockEmbeddedTorStatusCubit();
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.retry()).thenAnswer((_) async {});
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<EmbeddedTorStatusCubit>.value(
            value: cubit,
            child: const Scaffold(
              body: SizedBox.expand(),
              bottomNavigationBar: EmbeddedTorStatusIndicator(),
            ),
          ),
        ),
        GoRoute(
          path: '/tor',
          name: TorSettingsRoute.torSettings.name,
          builder: (_, _) => const Text('Tor settings destination'),
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
    await tester.pump();
    return cubit;
  }

  testWidgets('stays hidden until embedded routing is selected', (
    tester,
  ) async {
    await pumpIndicator(tester, const EmbeddedTorStatusState());
    expect(find.byType(InkWell), findsNothing);

    await pumpIndicator(
      tester,
      const EmbeddedTorStatusState(
        configurationLoaded: true,
        externalProxySelected: true,
      ),
    );
    expect(find.text('Tor not started'), findsNothing);
  });

  testWidgets('shows verified route details in a mobile sheet', (tester) async {
    await pumpIndicator(
      tester,
      EmbeddedTorStatusState(
        configurationLoaded: true,
        visible: true,
        connection: TorReady(
          TorRoute(
            source: TorSource.embedded,
            endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
            evidence: TorReadinessEvidence.embeddedBootstrap,
            transport: TorTransport.direct,
          ),
        ),
      ),
    );

    expect(find.text('Tor ready'), findsOneWidget);
    await tester.tap(find.text('Tor ready'));
    await tester.pumpAndSettle();

    expect(find.text('Embedded Tor status'), findsOneWidget);
    expect(find.text('127.0.0.1:41001'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);
    expect(
      find.text(
        'Circuit paths and throughput are not exposed by the embedded Tor engine.',
      ),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('exposes the status indicator as an accessible action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpIndicator(
        tester,
        EmbeddedTorStatusState(
          configurationLoaded: true,
          visible: true,
          connection: TorReady(
            TorRoute(
              source: TorSource.embedded,
              endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
              evidence: TorReadinessEvidence.embeddedBootstrap,
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.bySemanticsLabel('Tor ready'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('shows bootstrap progress and censorship guidance', (
    tester,
  ) async {
    await pumpIndicator(
      tester,
      const EmbeddedTorStatusState(
        configurationLoaded: true,
        visible: true,
        connection: TorConnecting(
          source: TorSource.embedded,
          progress: 0.42,
          diagnostic: TorDiagnostic.filtering,
          transport: TorTransport.snowflake,
        ),
      ),
    );

    expect(find.text('Connecting to Tor: 42%'), findsOneWidget);
    await tester.tap(find.text('Connecting to Tor: 42%'));
    await tester.pumpAndSettle();

    expect(find.text('Snowflake'), findsOneWidget);
    expect(find.textContaining('connection is being filtered'), findsOneWidget);
  });

  testWidgets('keeps failure visible and retries from its details', (
    tester,
  ) async {
    final cubit = await pumpIndicator(
      tester,
      const EmbeddedTorStatusState(
        configurationLoaded: true,
        visible: true,
        connection: TorUnavailable(
          source: TorSource.embedded,
          failure: TorBootstrapFailure('bootstrap failed'),
        ),
      ),
    );

    expect(find.text('Tor unavailable'), findsOneWidget);
    await tester.tap(find.text('Tor unavailable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => cubit.retry()).called(1);
    expect(find.text('Tor unavailable'), findsNWidgets(2));
  });

  testWidgets('uses a dialog on wide screens', (tester) async {
    await pumpIndicator(
      tester,
      const EmbeddedTorStatusState(configurationLoaded: true, visible: true),
      size: const Size(900, 800),
    );

    await tester.tap(find.text('Tor not started'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('pushes settings without discarding the current route', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final cubit = _MockEmbeddedTorStatusCubit();
    when(() => cubit.state).thenReturn(
      const EmbeddedTorStatusState(configurationLoaded: true, visible: true),
    );
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => BlocProvider<EmbeddedTorStatusCubit>.value(
            value: cubit,
            child: const Scaffold(
              body: Text('Home'),
              bottomNavigationBar: EmbeddedTorStatusIndicator(),
            ),
          ),
        ),
        GoRoute(
          path: '/tor',
          name: TorSettingsRoute.torSettings.name,
          builder: (_, _) => const Text('Tor settings destination'),
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
    await tester.tap(find.text('Tor not started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tor Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Tor settings destination'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
