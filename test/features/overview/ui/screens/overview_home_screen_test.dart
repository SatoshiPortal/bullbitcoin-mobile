import 'package:bitcoin_price/testing.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:bull_ui/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:overview/overview.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

import '../../support/overview_home_harness.dart';

const pickerCopy = (
  defaultBitcoinTitle: 'BTC',
  defaultLiquidTitle: 'Liquid',
  bitcoinDescription: 'Bitcoin',
  liquidDescription: 'Liquid network',
  remoteDescription: 'Remote',
  watchOnlyDescription: 'Watch',
  unavailableLabel: 'Unavailable',
  silentTitle: 'Silent',
  silentDescription: 'Experimental',
);
const warningCopy = (
  bitcoinDown: 'BTC down',
  liquidDown: 'Liquid down',
  bothDown: 'Both down',
  electrumAction: 'Electrum',
  tor: (title: 'Tor down', description: 'Tor'),
  swap: (title: 'Swap down', description: 'Swap'),
  balancesMayBeStale: 'Stale',
  loadFailed: 'Failed',
  cannotDeleteDefaultWallet: 'Default',
  cannotDeleteWithOngoingSwaps: 'Swaps',
  walletNotFound: 'Missing',
  unexpected: 'Error',
  retryHint: 'Retry',
);

/// Pumps the public Home screen over the harness with inert caller slots.
Future<GoRouter> pumpHome(
  WidgetTester tester,
  OverviewHomeHarness h, {
  ValueChanged<OverviewWalletSelection>? onOpenWallet,
  ValueChanged<HomeWarningDestination>? onOpenWarning,
  VoidCallback? onOpenSilent,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: OverviewHomeScreen(
            controller: h.controller,
            homePath: '/',
            header: (
              context, {
              required totalSat,
              required isLoading,
              required hideAmounts,
            }) => Text('total:$totalSat'),
            announcements: const Text('announcements'),
            consolidation: const Text('consolidation'),
            empty: const Text('empty'),
            backupWarning: const Text('backup'),
            ark: (refresh, scope) => const Text('ark'),
            bottomActions: const Text('actions'),
            walletPickerCopy: pickerCopy,
            warningsCopy: warningCopy,
            onOpenWallet: onOpenWallet ?? (_) {},
            onOpenWarning: onOpenWarning ?? (_) {},
            onOpenSilent: onOpenSilent,
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [BitcoinPriceFixture.prices()],
      child: MaterialApp.router(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [bullUiLocalizationsDelegate],
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  return router;
}

Future<void> disposeHome(
  WidgetTester tester,
  OverviewHomeHarness h,
  GoRouter router,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  router.dispose();
  await tester.runAsync(h.close);
}

void main() {
  testWidgets('due backup card remains visible at zero and after dismissal', (
    tester,
  ) async {
    final h = OverviewHomeHarness();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('first', isDefault: true, balanceSat: 0),
      ]),
    );
    final router = await pumpHome(tester, h);
    await tester.pump();
    expect(find.text('backup'), findsOneWidget);
    h.controller.dismissBackupWarning();
    await tester.pump();
    expect(find.text('backup'), findsOneWidget);
    await disposeHome(tester, h, router);
  });

  testWidgets('Home composes wallet, warning, backup and Silent callbacks', (
    tester,
  ) async {
    final h = OverviewHomeHarness();
    h.silent.enabled = true;
    h.silent.setUp = true;
    h.silent.wallet = silentWallet(7, network: BitcoinNetwork.mainnet);
    final row = homeWallet(
      'first',
      network: BitcoinNetwork.mainnet,
      label: 'First',
      balanceSat: 5,
    );
    h.source.publish(snapshot(OverviewCatalogueStatus.ready, [row]));

    final selected = <OverviewWalletSelection>[];
    final warnings = <HomeWarningDestination>[];
    var silentOpens = 0;
    final router = await pumpHome(
      tester,
      h,
      onOpenWallet: selected.add,
      onOpenWarning: warnings.add,
      onOpenSilent: () => silentOpens++,
    );
    await tester.pump();
    h.emitElectrum(row.entry.key, isLiquid: false, success: false);
    await tester.pump();
    await tester.pump();

    expect(find.text('total:12'), findsOneWidget);
    expect(find.text('announcements'), findsOneWidget);
    expect(find.text('backup'), findsOneWidget);
    expect(find.text('BTC down'), findsOneWidget);
    expect(find.text('empty'), findsNothing);

    final picker = tester.widget<WalletPicker>(find.byType(WalletPicker));
    expect(picker.rows.single.selection.key, row.entry.key);
    expect(picker.rows.single.origin, 'first');
    expect(picker.silent?.balanceSat, 7);
    picker.onSelected?.call(picker.rows.single.selection);
    expect(selected.single.key, row.entry.key);
    picker.silent?.onOpen();
    expect(silentOpens, 1);

    final warning = tester.widget<OverviewHomeWarnings>(
      find.byType(OverviewHomeWarnings),
    );
    warning.onOpen(HomeWarningDestination.electrum);
    expect(warnings, [HomeWarningDestination.electrum]);

    await disposeHome(tester, h, router);
  });

  testWidgets('an empty catalogue replaces Home with the onboarding slot', (
    tester,
  ) async {
    final h = OverviewHomeHarness();
    h.source.publish(emptySnapshot);
    final router = await pumpHome(tester, h);
    await tester.pump();

    expect(find.text('empty'), findsOneWidget);
    expect(find.byType(WalletPicker), findsNothing);
    expect(find.text('announcements'), findsNothing);

    await disposeHome(tester, h, router);
  });

  testWidgets('Home keeps the reviewed top-to-bottom order', (tester) async {
    final h = OverviewHomeHarness();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet(
          'first',
          network: BitcoinNetwork.mainnet,
          label: 'First',
          balanceSat: 5,
        ),
      ]),
    );
    final router = await pumpHome(tester, h);
    await tester.pump();

    double top(String finder) => tester.getTopLeft(find.text(finder)).dy;

    expect(top('announcements'), lessThan(top('consolidation')));
    expect(top('consolidation'), lessThan(top('First')));
    expect(top('First'), lessThan(top('ark')));

    await disposeHome(tester, h, router);
  });
}
