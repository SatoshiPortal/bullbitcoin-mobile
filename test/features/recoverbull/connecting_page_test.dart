import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/connecting_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
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
  Future<void> pumpPage(WidgetTester tester, RecoverBullState state) async {
    final bloc = _StaticBloc(state);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<RecoverBullBloc>.value(
          value: bloc,
          child: const ConnectingPage(),
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
      const RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        torConnection: tor.TorConnecting(
          source: tor.TorSource.embedded,
          progress: 0.45,
        ),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.recoverbullCheckingConnection), findsOneWidget);
    expect(find.text(l10n.recoverbullTorNetwork), findsOneWidget);
    expect(find.text(l10n.recoverbullRecoverBullServer), findsOneWidget);
    expect(find.byKey(const ValueKey('tor-bull-direct')), findsOneWidget);
    expect(find.text(l10n.torSettingsModeDirectDescription), findsOneWidget);
  });

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

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byKey(const ValueKey('tor-bull-ready')), findsOneWidget);
    expect(find.byKey(const ValueKey('tor-bull-direct')), findsNothing);
    expect(find.text(l10n.recoverbullConnectingTor), findsOneWidget);
  });

  // The headline of this screen: a blockage that outlives the grace period has
  // to be explained *while Tor is still connecting*. It never rendered, because
  // the only path to the explanation was gated on a failed phase — and a
  // connecting Tor with a pending server check has neither.
  testWidgets('explains a settled blockage while still connecting', (
    tester,
  ) async {
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
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<RecoverBullBloc>.value(
          value: bloc,
          child: const ConnectingPage(),
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

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // Inside the grace period: still silent, on purpose.
    expect(find.text(l10n.recoverbullTorOffline), findsNothing);

    // Two clocks have to move. The grace period is measured against the wall
    // clock, which `pump` does not advance, so the wait is real. The rebuild then
    // comes from the one-second ticker, which only fires when the *fake* clock
    // advances. Six seconds of CI time is the price of pinning what shipped here.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 6)),
    );
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

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.torSettingsDescCensored), findsOneWidget);
    expect(find.text(l10n.recoverbullTorCantStart), findsNothing);
  });

  testWidgets('shows the filtered mascot after the grace period', (
    tester,
  ) async {
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
    );

    expect(find.byKey(const ValueKey('tor-bull-filtered')), findsNothing);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 6)),
    );
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
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.recoverbullRetry), findsOneWidget);
  });
}
