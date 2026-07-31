import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/connecting_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tor/tor.dart' as tor;

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
    expect(find.text(l10n.recoverbullPleaseWait), findsOneWidget);
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
