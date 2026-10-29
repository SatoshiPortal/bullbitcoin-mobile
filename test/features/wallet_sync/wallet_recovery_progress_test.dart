import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_status.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_options_failure.dart';
import 'package:bb_mobile/features/wallet_sync/ui/widgets/wallet_recovery_panel.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_sync/transaction_sync.dart';

final _now = DateTime.utc(2026, 10, 28, 12);
const _key = WalletNetworkKey('public-wallet', 'bitcoin', 'mainnet');
BitcoinSyncProgress _progress(
  BitcoinSyncPhase phase, {
  double? fraction,
  int operationId = 1,
  DateTime? startedAt,
}) => BitcoinSyncProgress(
  key: _key,
  phase: phase,
  fraction: fraction,
  isRecovery: true,
  operationId: operationId,
  startHeight: 100,
  reachedHeight: 150,
  targetHeight: 200,
  startedAt: startedAt ?? _now,
);
WalletSyncStatus _status(BitcoinSyncPhase phase, {double? fraction}) =>
    WalletSyncStatus(
      progress: _progress(phase, fraction: fraction),
      recoveryRequired: phase != BitcoinSyncPhase.done,
      scanDate: DateTime.utc(2023, 3),
      lastSuccessfulSync: _now.subtract(const Duration(minutes: 3)),
    );
Widget _app(Widget child, {String locale = 'en', bool dark = false}) =>
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.themeData(dark ? AppThemeType.dark : AppThemeType.light),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
Widget _panel(
  WalletSyncStatus status, {
  VoidCallback? retry,
  VoidCallback? settings,
  VoidCallback? tor,
}) => WalletRecoveryPanel(
  status: status,
  now: () => _now,
  onRetry: retry ?? () {},
  onSettings: settings ?? () {},
  onTorSettings: tor ?? () {},
);
Future<void> _close(WidgetTester tester) async {
  BullSnackBar.dismiss();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  test(
    'ETA requires 30 seconds of steady samples and resets when rate drops',
    () {
      final rate = RecoveryRate();
      for (var seconds = 0; seconds < 30; seconds += 5) {
        expect(
          rate.observe(
            0.1 + seconds / 100,
            _now.add(Duration(seconds: seconds)),
          ),
          isNull,
        );
      }
      expect(rate.observe(0.4, _now.add(const Duration(seconds: 30))), 1);
      expect(
        rate.observe(0.405, _now.add(const Duration(seconds: 35))),
        isNull,
      );
      expect(
        rate.observe(0.405, _now.add(const Duration(seconds: 40))),
        isNull,
      );
      expect(rate.observe(0.5, _now.add(const Duration(seconds: 55))), isNull);
    },
  );
  test('ETA expires on stalled progress and outside the filter phase', () {
    final status = WalletSyncStatus(
      progress: _progress(BitcoinSyncPhase.checkingBlocks, fraction: 0.5),
      etaMinutes: 4,
      rateObservedAt: _now,
    );
    expect(status.etaAt(_now), 4);
    expect(status.etaAt(_now.add(const Duration(seconds: 11))), isNull);
    expect(
      status
          .copyWith(
            progress: _progress(BitcoinSyncPhase.downloadingTransactions),
            etaMinutes: 4,
            rateObservedAt: _now,
          )
          .etaAt(_now),
      isNull,
    );
  });
  for (final dark in [false, true]) {
    for (final (phase, text) in [
      (BitcoinSyncPhase.findingPeers, 'Finding peers'),
      (BitcoinSyncPhase.checkingBlocks, 'Checking blocks'),
      (
        BitcoinSyncPhase.downloadingTransactions,
        'Downloading your transactions',
      ),
    ]) {
      testWidgets('$phase renders with incomplete balance (dark=$dark)', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(
            _panel(
              _status(
                phase,
                fraction: phase == BitcoinSyncPhase.findingPeers ? null : 0.5,
              ),
            ),
            dark: dark,
          ),
        );
        expect(find.text(text), findsOneWidget);
        expect(
          find.text('Incomplete — still checking older blocks'),
          findsOneWidget,
        );
        expect(
          find.text('Keep the app open for the fastest sync'),
          findsOneWidget,
        );
        expect(find.textContaining('min left'), findsNothing);
        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(
          indicator.value,
          phase == BitcoinSyncPhase.findingPeers ? isNull : 0.5,
        );
        if (phase != BitcoinSyncPhase.findingPeers) {
          expect(find.text('50 of 100 blocks'), findsOneWidget);
        }
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.liveRegion == true,
          ),
          findsOneWidget,
        );
        semantics.dispose();
        await _close(tester);
      });
    }
  }
  testWidgets('peer wait uses the two-minute explanation', (tester) async {
    await tester.pumpWidget(
      _app(
        _panel(
          WalletSyncStatus(
            progress: _progress(
              BitcoinSyncPhase.findingPeers,
              startedAt: _now.subtract(const Duration(minutes: 2)),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Still looking for peers'), findsOneWidget);
    await _close(tester);
  });
  testWidgets('ETA and counts are localized and remain below completion', (
    tester,
  ) async {
    final status = WalletSyncStatus(
      progress: _progress(BitcoinSyncPhase.checkingBlocks, fraction: 0.999999),
      etaMinutes: 4,
      rateObservedAt: _now,
    );
    await tester.pumpWidget(_app(_panel(status)));
    expect(find.text('About 4 min left'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      lessThan(1),
    );
    await _close(tester);
  });
  testWidgets(
    'live announcements change only at ten percent or phase boundaries',
    (tester) async {
      String label() =>
          tester
              .widgetList<Semantics>(find.byType(Semantics))
              .firstWhere((widget) => widget.properties.liveRegion == true)
              .properties
              .label ??
          '';
      await tester.pumpWidget(
        _app(_panel(_status(BitcoinSyncPhase.checkingBlocks, fraction: 0.21))),
      );
      final first = label();
      await tester.pumpWidget(
        _app(_panel(_status(BitcoinSyncPhase.checkingBlocks, fraction: 0.29))),
      );
      expect(label(), first);
      await tester.pumpWidget(
        _app(_panel(_status(BitcoinSyncPhase.checkingBlocks, fraction: 0.31))),
      );
      expect(label(), isNot(first));
      await tester.pumpWidget(
        _app(
          _panel(
            _status(BitcoinSyncPhase.downloadingTransactions, fraction: 0.31),
          ),
        ),
      );
      expect(label(), contains('Downloading your transactions'));
      await _close(tester);
    },
  );

  testWidgets('completion collapses the recovery panel', (tester) async {
    await tester.pumpWidget(
      _app(_panel(_status(BitcoinSyncPhase.checkingBlocks, fraction: 0.9))),
    );
    await tester.pumpWidget(
      _app(_panel(_status(BitcoinSyncPhase.done, fraction: 1))),
    );
    await tester.pump();
    expect(find.text('Incomplete — still checking older blocks'), findsNothing);
    await _close(tester);
  });
  for (final (failure, text, tor) in <(WalletSyncOptionsFailure, String, bool)>[
    (
      const WalletSyncNoPeersFailure(),
      'Couldn’t reach the Bitcoin network privately. Your balance is from 3 min ago.',
      false,
    ),
    (
      const WalletSyncTorFailure(),
      'Tor isn’t connected, so private sync is paused.',
      true,
    ),
    (const WalletSyncPausedFailure(), 'Sync paused — will resume', false),
    (const WalletSyncUnexpectedFailure(), 'Oops! Something went wrong', false),
  ]) {
    testWidgets('$failure shows localized actions without a running bar', (
      tester,
    ) async {
      var retry = 0;
      var settings = 0;
      var torSettings = 0;
      await tester.pumpWidget(
        _app(
          _panel(
            _status(BitcoinSyncPhase.findingPeers).copyWith(failure: failure),
            retry: () => retry++,
            settings: () => settings++,
            tor: () => torSettings++,
          ),
        ),
      );
      if (failure is! WalletSyncUnexpectedFailure) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.tap(find.text(tor ? 'Open Tor settings' : 'Sync settings'));
      await tester.pump();
      expect(retry, 1);
      expect(tor ? torSettings : settings, 1);
      await _close(tester);
    });
  }
  testWidgets('a new failure takes priority over the empty-recovery notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _panel(
          _status(BitcoinSyncPhase.done).copyWith(
            emptyRecovery: true,
            failure: const WalletSyncTorFailure(),
          ),
        ),
      ),
    );
    expect(
      find.text('Tor isn’t connected, so private sync is paused.'),
      findsOneWidget,
    );
    expect(find.textContaining('No transactions found'), findsNothing);
    await _close(tester);
  });

  testWidgets('empty recovery gives the resolved month and earlier-date action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _panel(_status(BitcoinSyncPhase.done).copyWith(emptyRecovery: true)),
      ),
    );
    expect(
      find.text(
        'No transactions found since March 2023. If you used this wallet earlier, scan from an earlier date.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sync settings'), findsOneWidget);
    await _close(tester);
  });
  for (final locale in ['fr', 'ar']) {
    testWidgets('incomplete ring and recovery support $locale', (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              _panel(_status(BitcoinSyncPhase.checkingBlocks, fraction: 0.5)),
              WalletIncompleteBalance(
                status: _status(BitcoinSyncPhase.checkingBlocks, fraction: 0.5),
              ),
            ],
          ),
          locale: locale,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      if (locale == 'fr') expect(find.text('50 blocs sur 100'), findsOneWidget);
      if (locale == 'ar') {
        expect(
          Directionality.of(tester.element(find.byType(WalletRecoveryPanel))),
          TextDirection.rtl,
        );
      }
      expect(tester.takeException(), isNull);
      await _close(tester);
    });
  }
  testWidgets('sending found coins has a warning without disabling controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        WalletIncompleteBalance(
          status: _status(BitcoinSyncPhase.findingPeers),
          sending: true,
        ),
      ),
    );
    expect(
      find.text(
        'Your balance is incomplete while older blocks are checked. Sending may be unavailable until the current sync operation finishes.',
      ),
      findsOneWidget,
    );
    await _close(tester);
  });
}
