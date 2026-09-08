import 'dart:async';

import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/ui/screens/connecting_page.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_tor/tor.dart' as tor;

/// Holds one state and never emits. The page is a pure projection of the
/// state, so nothing here needs the real bloc's dependency graph.
class _StaticBloc extends Fake implements RecoverBullBloc {
  _StaticBloc(this._state);

  final RecoverBullState _state;

  @override
  RecoverBullState get state => _state;

  @override
  Stream<RecoverBullState> get stream => const Stream.empty();

  @override
  Future<void> close() async {}
}

/// Emits on demand, so a test can replay the sequence the device produces.
class _MutableBloc extends Fake implements RecoverBullBloc {
  RecoverBullState _state;
  final _states = StreamController<RecoverBullState>.broadcast();

  _MutableBloc(this._state);

  @override
  RecoverBullState get state => _state;

  @override
  Stream<RecoverBullState> get stream => _states.stream;

  void pushState(RecoverBullState state) {
    _state = state;
    _states.add(state);
  }

  @override
  void add(RecoverBullEvent event) {}

  @override
  Future<void> close() => _states.close();
}

class _RouteObserver extends NavigatorObserver {
  int replacements = 0;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacements++;
  }
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    RecoverBullState state, {
    DateTime Function()? now,
  }) async {
    final bloc = _StaticBloc(state);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: BlocProvider<RecoverBullBloc>.value(
          value: bloc,
          child: ConnectingPage(now: now ?? DateTime.now),
        ),
      ),
    );
    await tester.pump();
  }

  // The screen the user stares at for the whole Tor bootstrap. It rendered an
  // empty body on device — the title, both phase rows and the reassurance line
  // were laid out but never painted.
  testWidgets('shows both phases while Tor is still connecting', (
    tester,
  ) async {
    await pumpPage(
      tester,
      RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        torConnection: tor.TorConnecting(
          source: tor.TorSource.embedded,
          progress: 0.45,
        ),
      ),
    );

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.text(l10n.recoverbullCheckingConnection), findsOneWidget);
    expect(find.text(l10n.recoverbullTorNetwork), findsOneWidget);
    expect(find.text(l10n.recoverbullRecoverBullServer), findsOneWidget);
    expect(find.byKey(const ValueKey('tor-bull-direct')), findsOneWidget);
    expect(find.text(l10n.torSettingsModeDirectDescription), findsOneWidget);
  });

  testWidgets('offers Tor Settings for an external proxy failure', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        failure: ExternalTorProxyUnavailableFailure(),
        torConnection: tor.TorUnavailable(
          source: tor.TorSource.external,
          failure: tor.TorExternalProxyUnavailableFailure(),
        ),
      ),
    );

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.text(l10n.torSettingsTitle), findsOneWidget);
    expect(
      find.text(l10n.torSettingsExternalProxyUnavailableDescription),
      findsOneWidget,
    );
    expect(find.text(l10n.torSettingsDescDisconnected), findsNothing);
  });

  testWidgets('does not offer Tor Settings for a key-server failure', (
    tester,
  ) async {
    await pumpPage(
      tester,
      RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        failure: KeyServerConnectionFailure(),
        keyServerStatus: KeyServerStatus.offline,
        torConnection: tor.TorReady(
          tor.TorRoute(
            source: tor.TorSource.embedded,
            endpoint: tor.TorProxyEndpoint(host: '127.0.0.1', port: 41001),
            evidence: tor.TorReadinessEvidence.embeddedBootstrap,
            transport: tor.TorTransport.direct,
          ),
        ),
      ),
    );

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.text(l10n.torSettingsTitle), findsNothing);
  });

  testWidgets('uses the attributed Tor failure instead of blaming the server', (
    tester,
  ) async {
    await pumpPage(
      tester,
      RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        failure: const KeyServerTorFailure(),
        keyServerStatus: KeyServerStatus.offline,
        torConnection: tor.TorReady(
          tor.TorRoute(
            source: tor.TorSource.embedded,
            endpoint: tor.TorProxyEndpoint(host: '127.0.0.1', port: 41001),
            evidence: tor.TorReadinessEvidence.embeddedBootstrap,
            transport: tor.TorTransport.direct,
          ),
        ),
      ),
    );

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.text(l10n.recoverbullErrorTorConnection), findsOneWidget);
    expect(find.text(l10n.recoverbullServerUnreachableTorOk), findsNothing);
  });

  testWidgets('uses the attributed server failure message', (tester) async {
    await pumpPage(
      tester,
      RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        failure: const KeyServerOnionUnreachableFailure(),
        keyServerStatus: KeyServerStatus.offline,
        torConnection: tor.TorReady(
          tor.TorRoute(
            source: tor.TorSource.embedded,
            endpoint: tor.TorProxyEndpoint(host: '127.0.0.1', port: 41001),
            evidence: tor.TorReadinessEvidence.embeddedBootstrap,
            transport: tor.TorTransport.direct,
          ),
        ),
      ),
    );

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.text(l10n.recoverbullErrorOnionUnavailable), findsOneWidget);
    expect(find.text(l10n.recoverbullServerUnreachableTorOk), findsNothing);
  });

  testWidgets('keeps the phase-based fallback when no cause is attributed', (
    tester,
  ) async {
    await pumpPage(
      tester,
      RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        failure: const KeyServerConnectionFailure(),
        keyServerStatus: KeyServerStatus.offline,
        torConnection: tor.TorReady(
          tor.TorRoute(
            source: tor.TorSource.embedded,
            endpoint: tor.TorProxyEndpoint(host: '127.0.0.1', port: 41001),
            evidence: tor.TorReadinessEvidence.embeddedBootstrap,
            transport: tor.TorTransport.direct,
          ),
        ),
      ),
    );

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.text(l10n.recoverbullServerUnreachableTorOk), findsOneWidget);
  });

  testWidgets('keeps the Tor fallback when it was never ready', (tester) async {
    await pumpPage(
      tester,
      const RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        failure: KeyServerConnectionFailure(),
        keyServerStatus: KeyServerStatus.offline,
        torConnection: tor.TorUnavailable(
          source: tor.TorSource.embedded,
          failure: tor.TorBootstrapFailure('offline'),
        ),
      ),
    );

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.text(l10n.recoverbullTorCantStart), findsOneWidget);
    expect(find.text(l10n.recoverbullServerUnreachableTorOk), findsNothing);
  });

  testWidgets('keeps an explicit Arti diagnostic above an attribution', (
    tester,
  ) async {
    await pumpPage(
      tester,
      RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        failure: KeyServerTorFailure(),
        keyServerStatus: KeyServerStatus.offline,
        torConnection: tor.TorUnavailable(
          source: tor.TorSource.embedded,
          failure: tor.TorBootstrapFailure(
            'offline',
            tor.TorDiagnostic.offline,
          ),
        ),
      ),
    );

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.text(l10n.recoverbullTorOffline), findsOneWidget);
    expect(find.text(l10n.recoverbullErrorTorConnection), findsNothing);
  });

  testWidgets(
    'marks Tor failed when its attributed cause conflicts with ready',
    (tester) async {
      await pumpPage(
        tester,
        RecoverBullState(
          flow: RecoverBullFlow.recoverVault,
          failure: KeyServerTorFailure(),
          keyServerStatus: KeyServerStatus.offline,
          torConnection: tor.TorReady(
            tor.TorRoute(
              source: tor.TorSource.embedded,
              endpoint: tor.TorProxyEndpoint(host: '127.0.0.1', port: 41001),
              evidence: tor.TorReadinessEvidence.embeddedBootstrap,
              transport: tor.TorTransport.direct,
            ),
          ),
        ),
      );

      final l10n = await RecoverBullLocalizations.delegate.load(
        const Locale('en'),
      );
      final torCard = find.byKey(const ValueKey('tor-phase-card'));
      expect(
        find.descendant(
          of: torCard,
          matching: find.text(l10n.recoverbullFailed),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: torCard,
          matching: find.text(l10n.recoverbullConnected),
        ),
        findsNothing,
      );
    },
  );

  // Tor being usable and the key server answering are two different facts,
  // separated by 17-24s on device. Holding the mascot on "searching" for that
  // whole window told the user nothing had happened yet.
  testWidgets('shows Tor ready while the RecoverBull server is checked', (
    tester,
  ) async {
    await pumpPage(
      tester,
      RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        torConnection: tor.TorReady(
          tor.TorRoute(
            source: tor.TorSource.embedded,
            endpoint: tor.TorProxyEndpoint(host: '127.0.0.1', port: 41001),
            evidence: tor.TorReadinessEvidence.embeddedBootstrap,
            transport: tor.TorTransport.direct,
          ),
        ),
        keyServerStatus: KeyServerStatus.connecting,
      ),
    );

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.byKey(const ValueKey('tor-bull-ready')), findsOneWidget);
    expect(find.byKey(const ValueKey('tor-bull-direct')), findsNothing);
    expect(
      find.text(l10n.recoverbullConnectedTorCheckingServer),
      findsOneWidget,
    );
    expect(find.text('Connecting to Key Server over Tor.'), findsNothing);
  });

  testWidgets('does not show refresh progress beside the connected verdict', (
    tester,
  ) async {
    final route = tor.TorRoute(
      source: tor.TorSource.embedded,
      endpoint: tor.TorProxyEndpoint(host: '127.0.0.1', port: 41001),
      evidence: tor.TorReadinessEvidence.embeddedBootstrap,
      transport: tor.TorTransport.direct,
    );

    await pumpPage(
      tester,
      RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        torConnection: tor.TorReady(route),
      ),
    );

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.text(l10n.recoverbullConnected), findsOneWidget);
    expect(find.textContaining('42%'), findsNothing);
    expect(find.textContaining('direct'), findsNothing);
  });

  testWidgets('shows reconnection and current progress after a durable loss', (
    tester,
  ) async {
    final route = tor.TorRoute(
      source: tor.TorSource.embedded,
      endpoint: tor.TorProxyEndpoint(host: '127.0.0.1', port: 41001),
      evidence: tor.TorReadinessEvidence.embeddedBootstrap,
      transport: tor.TorTransport.direct,
    );
    final ready = RecoverBullState(
      flow: RecoverBullFlow.recoverVault,
      torConnection: tor.TorReady(route),
    );
    final bloc = _MutableBloc(
      const RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        torConnection: tor.TorConnecting(source: tor.TorSource.embedded),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: BlocProvider<RecoverBullBloc>.value(
          value: bloc,
          child: const ConnectingPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    bloc.pushState(ready);
    await tester.pump();
    bloc.pushState(
      ready.copyWith(
        torConnection: const tor.TorConnecting(
          source: tor.TorSource.embedded,
          progress: 0.45,
        ),
      ),
    );
    await tester.pump();

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.text(l10n.recoverbullReconnecting), findsOneWidget);
    expect(find.textContaining('45%'), findsOneWidget);
    await bloc.close();
  });

  testWidgets('keeps one elapsed clock across an Arti republication', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1);
    final route = tor.TorRoute(
      source: tor.TorSource.embedded,
      endpoint: tor.TorProxyEndpoint(host: '127.0.0.1', port: 41001),
      evidence: tor.TorReadinessEvidence.embeddedBootstrap,
      transport: tor.TorTransport.direct,
    );
    final initial = RecoverBullState(
      flow: RecoverBullFlow.recoverVault,
      torConnection: tor.TorReady(route),
      keyServerStatus: KeyServerStatus.connecting,
    );
    final bloc = _MutableBloc(initial);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: BlocProvider<RecoverBullBloc>.value(
          value: bloc,
          child: ConnectingPage(now: () => now),
        ),
      ),
    );
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('0:10'), findsOneWidget);

    bloc.pushState(
      initial.copyWith(
        torConnection: const tor.TorConnecting(
          source: tor.TorSource.embedded,
          diagnostic: tor.TorDiagnostic.offline,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('0:10'), findsOneWidget);
    await bloc.close();
  });

  testWidgets('resets the elapsed clock only after an explicit Retry', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1);
    const initial = RecoverBullState(
      flow: RecoverBullFlow.recoverVault,
      torConnection: tor.TorConnecting(
        source: tor.TorSource.embedded,
        diagnostic: tor.TorDiagnostic.offline,
      ),
      keyServerStatus: KeyServerStatus.connecting,
    );
    final bloc = _MutableBloc(initial);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: BlocProvider<RecoverBullBloc>.value(
          value: bloc,
          child: ConnectingPage(now: () => now),
        ),
      ),
    );
    now = now.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('0:06'), findsOneWidget);
    final retry = find.text('Retry');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    expect(find.textContaining('0:00'), findsOneWidget);
    await bloc.close();
  });

  testWidgets(
    'shows Tor progress and an active server check before readiness',
    (tester) async {
      await pumpPage(
        tester,
        const RecoverBullState(
          flow: RecoverBullFlow.recoverVault,
          torConnection: tor.TorConnecting(
            source: tor.TorSource.embedded,
            progress: 0.45,
          ),
          keyServerStatus: KeyServerStatus.connecting,
          keyServerAttempt: 1,
          keyServerAttempts: 3,
        ),
      );

      final l10n = await RecoverBullLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(find.textContaining('45%'), findsOneWidget);
      expect(find.textContaining('1/3'), findsOneWidget);
      expect(find.text(l10n.recoverbullChecking), findsOneWidget);
      expect(find.text(l10n.recoverbullWaitingForTor), findsNothing);
    },
  );

  testWidgets('does not invent a percentage when Tor has no progress', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        torConnection: tor.TorConnecting(source: tor.TorSource.embedded),
      ),
    );

    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('shows a falling Arti progress value without smoothing it', (
    tester,
  ) async {
    final bloc = _MutableBloc(
      RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        torConnection: tor.TorConnecting(
          source: tor.TorSource.embedded,
          progress: 0.76,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: BlocProvider<RecoverBullBloc>.value(
          value: bloc,
          child: const ConnectingPage(),
        ),
      ),
    );
    await tester.pump();

    bloc.pushState(
      const RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        torConnection: tor.TorConnecting(
          source: tor.TorSource.embedded,
          progress: 0.42,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('42%'), findsOneWidget);
    expect(find.textContaining('76%'), findsNothing);
    await bloc.close();
  });

  testWidgets('shows elapsed time once outside the phase cards', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1);
    final bloc = _MutableBloc(
      RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        torConnection: tor.TorReady(
          tor.TorRoute(
            source: tor.TorSource.embedded,
            endpoint: tor.TorProxyEndpoint(host: '127.0.0.1', port: 41001),
            evidence: tor.TorReadinessEvidence.embeddedBootstrap,
            transport: tor.TorTransport.direct,
          ),
        ),
        keyServerStatus: KeyServerStatus.connecting,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: BlocProvider<RecoverBullBloc>.value(
          value: bloc,
          child: ConnectingPage(now: () => now),
        ),
      ),
    );
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));

    final elapsed = find.textContaining('0:10');
    expect(elapsed, findsOneWidget);
    expect(
      find.ancestor(
        of: elapsed,
        matching: find.byKey(const ValueKey('tor-phase-card')),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: elapsed,
        matching: find.byKey(const ValueKey('server-phase-card')),
      ),
      findsNothing,
    );
    await bloc.close();
  });

  // The headline of this screen: a blockage that outlives the grace period has
  // to be explained *while Tor is still connecting*. It never rendered, because
  // the only path to the explanation was gated on a failed phase — and a
  // connecting Tor with a pending server check has neither.
  testWidgets('explains a settled blockage while still connecting', (
    tester,
  ) async {
    var fakeNow = DateTime(2026, 1, 1);
    const connecting = RecoverBullState(
      flow: RecoverBullFlow.recoverVault,
      torConnection: tor.TorConnecting(
        source: tor.TorSource.embedded,
        progress: 0.08,
      ),
    );
    final bloc = _MutableBloc(connecting);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: BlocProvider<RecoverBullBloc>.value(
          value: bloc,
          child: ConnectingPage(now: () => fakeNow),
        ),
      ),
    );
    await tester.pump();

    // Arti starts reporting a blockage while it is still connecting.
    bloc.pushState(
      connecting.copyWith(
        torConnection: const tor.TorConnecting(
          source: tor.TorSource.embedded,
          progress: 0.08,
          diagnostic: tor.TorDiagnostic.offline,
        ),
      ),
    );
    await tester.pump();

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    // Inside the grace period: still silent, on purpose.
    expect(find.text(l10n.recoverbullTorOffline), findsNothing);

    fakeNow = fakeNow.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(l10n.recoverbullTorOffline), findsOneWidget);
    expect(find.text(l10n.recoverbullRetry), findsOneWidget);

    await bloc.close();
  });

  // The grace period exists to ride out a transient readiness dip, so it must
  // not swallow the reason a bootstrap gave up for good: this state reaches the
  // page with no prior TorConnecting event to start the grace clock.
  testWidgets('explains a filtered network on a failed bootstrap', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        torConnection: tor.TorUnavailable(
          source: tor.TorSource.embedded,
          failure: tor.TorBootstrapFailure(
            'filtered',
            tor.TorDiagnostic.filtering,
          ),
        ),
      ),
    );

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.text(l10n.torSettingsDescCensored), findsOneWidget);
    expect(find.text(l10n.recoverbullTorCantStart), findsNothing);
  });

  testWidgets('shows the filtered mascot after the grace period', (
    tester,
  ) async {
    var fakeNow = DateTime(2026, 1, 1);
    await pumpPage(
      tester,
      const RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        torConnection: tor.TorConnecting(
          source: tor.TorSource.embedded,
          progress: 0.08,
          diagnostic: tor.TorDiagnostic.filtering,
        ),
      ),
      now: () => fakeNow,
    );

    expect(find.byKey(const ValueKey('tor-bull-filtered')), findsNothing);

    fakeNow = fakeNow.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('tor-bull-filtered')), findsOneWidget);
  });

  // Tor republishes readiness on every directory refresh, so the success
  // condition is met repeatedly. Each repetition used to push another route.
  testWidgets('navigates once even when readiness repeats', (tester) async {
    const initial = RecoverBullState(
      flow: RecoverBullFlow.recoverVault,
      torConnection: tor.TorConnecting(
        source: tor.TorSource.embedded,
        progress: 0.3,
      ),
    );
    final bloc = _MutableBloc(initial);
    final observer = _RouteObserver();
    final route = tor.TorRoute(
      source: tor.TorSource.embedded,
      endpoint: tor.TorProxyEndpoint(host: '127.0.0.1', port: 41001),
      evidence: tor.TorReadinessEvidence.embeddedBootstrap,
      transport: tor.TorTransport.direct,
    );
    final ready = initial.copyWith(
      torConnection: tor.TorReady(route),
      keyServerStatus: KeyServerStatus.online,
    );

    await tester.pumpWidget(
      BlocProvider<RecoverBullBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: ThemeData(),
          localizationsDelegates:
              RecoverBullLocalizations.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: const ConnectingPage(),
        ),
      ),
    );
    await tester.pump();

    bloc.pushState(ready);
    await tester.pump();
    bloc.pushState(
      ready.copyWith(torConnection: tor.TorReady(route), keyServerAttempt: 2),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(observer.replacements, 1);
    await bloc.close();
  });

  testWidgets('offers a retry once Tor reports it cannot start', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        torConnection: tor.TorUnavailable(
          source: tor.TorSource.embedded,
          failure: tor.TorBootstrapFailure('no directory'),
        ),
      ),
    );

    final l10n = await RecoverBullLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.text(l10n.recoverbullRetry), findsOneWidget);
  });
}
