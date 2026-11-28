import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullCarousel, BullInfoCard;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:overview/overview.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show WalletKey;

import '../../support/overview_home_harness.dart';

const _copy = (
  bitcoinDown: 'Bitcoin unavailable',
  liquidDown: 'Liquid unavailable',
  bothDown: 'Both unavailable',
  electrumAction: 'Electrum settings',
  tor: (title: 'Tor unavailable', description: 'Tor settings'),
  swap: (title: 'Swap unavailable', description: 'Swap settings'),
  balancesMayBeStale: 'Balances may be stale',
  loadFailed: 'Load failed',
  cannotDeleteDefaultWallet: 'Default wallet',
  cannotDeleteWithOngoingSwaps: 'Ongoing swaps',
  walletNotFound: 'Wallet not found',
  unexpected: 'Unexpected error',
  retryHint: 'Try again',
);

void main() {
  testWidgets('opening a network warning does not dismiss it', (tester) async {
    final h = OverviewHomeHarness();
    addTearDown(h.close);
    await tester.runAsync(() async {
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [homeWallet('btc')]),
      );
      await flushEvents();
      h.emitElectrum(
        WalletKey(id: 'btc', network: BitcoinNetwork.regtest),
        isLiquid: false,
        success: false,
      );
      await flushEvents();
    });
    final destinations = <HomeWarningDestination>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        home: Scaffold(
          body: ValueListenableBuilder<OverviewHomeState>(
            valueListenable: h.controller,
            builder: (_, state, _) => OverviewHomeWarnings(
              network: state.networkWarnings,
              swapServerUnreachable: state.swapServerUnreachable,
              loadFailure: state.loadFailure,
              copy: _copy,
              backup: null,
              onOpen: destinations.add,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Bitcoin unavailable'), findsOneWidget);
    final warningsBefore = h.controller.current.networkWarnings;
    final card = tester.widget<BullInfoCard>(find.byType(BullInfoCard).first);
    card.onTap?.call();
    await tester.runAsync(flushEvents);
    await tester.pump();
    expect(destinations, [HomeWarningDestination.electrum]);
    expect(h.controller.current.networkWarnings, warningsBefore);
    expect(find.text('Bitcoin unavailable'), findsOneWidget);
    expect(
      tester.widget<BullCarousel>(find.byType(BullCarousel)).children,
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
