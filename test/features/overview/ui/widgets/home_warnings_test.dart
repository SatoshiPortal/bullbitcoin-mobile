import 'package:backups/backups.dart' show BackupCard;
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullCarousel, BullInfoCard;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:overview/overview.dart';

const _bitcoinDown = WalletWarning(
  reason: ElectrumServerDown.bitcoin,
  action: WalletWarningAction.electrumSettings,
  type: WarningType.error,
);
const _torDown = WalletWarning(
  reason: ElectrumServerDown.both,
  action: WalletWarningAction.torSettings,
  type: WarningType.error,
);

HomeWarningsCopy _copy(BuildContext context) => (
  bitcoinDown: context.loc.walletWarningElectrumBitcoinDown,
  liquidDown: context.loc.walletWarningElectrumLiquidDown,
  bothDown: context.loc.walletWarningElectrumBothDown,
  electrumAction: context.loc.walletWarningElectrumAction,
  tor: (
    title: context.loc.torSettingsExternalProxyUnavailable,
    description: context.loc.torSettingsExternalProxyUnavailableDescription,
  ),
  swap: (
    title: context.loc.walletWarningSwapServerUnreachable,
    description: context.loc.walletWarningSwapServerAction,
  ),
  balancesMayBeStale: context.loc.walletBalancesMayBeStale,
  loadFailed: context.loc.walletLoadFailed,
  cannotDeleteDefaultWallet: context.loc.walletDeletionErrorDefaultWallet,
  cannotDeleteWithOngoingSwaps: context.loc.walletDeletionErrorOngoingSwaps,
  walletNotFound: context.loc.walletDeletionErrorWalletNotFound,
  unexpected: context.loc.oopsSomethingWentWrong,
  retryHint: context.loc.walletLoadFailedRetryHint,
);

Future<void> _pump(
  WidgetTester tester, {
  List<WalletWarning> network = const [],
  OverviewLoadFailure? failure,
  bool swapDown = false,
  VoidCallback? onBackup,
  ValueChanged<HomeWarningDestination>? onOpen,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => OverviewHomeWarnings(
            network: network,
            swapServerUnreachable: swapDown,
            loadFailure: failure,
            copy: _copy(context),
            backup: onBackup == null
                ? null
                : BackupCard(
                    icon: AssetImage(Assets.misc.passwordbook.path),
                    onTap: onBackup,
                  ),
            onOpen: onOpen ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Tor action overrides a Bitcoin Electrum failure copy', (
    tester,
  ) async {
    await _pump(
      tester,
      network: [
        const WalletWarning(
          reason: ElectrumServerDown.bitcoin,
          action: WalletWarningAction.torSettings,
          type: WarningType.error,
        ),
      ],
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(BullCarousel)));
    expect(find.text(l10n.torSettingsExternalProxyUnavailable), findsOneWidget);
    expect(
      find.text(l10n.torSettingsExternalProxyUnavailableDescription),
      findsOneWidget,
    );
    expect(find.text('Bitcoin electrum server failure'), findsNothing);
  });
  testWidgets('network and backup combinations stay independent', (
    tester,
  ) async {
    for (final hasNetwork in [false, true]) {
      for (final hasBackup in [false, true]) {
        await _pump(
          tester,
          network: hasNetwork ? [_bitcoinDown] : [],
          onBackup: hasBackup ? () {} : null,
        );
        expect(
          find.byType(BullCarousel),
          hasNetwork ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(BackupCard),
          hasBackup ? findsOneWidget : findsNothing,
        );
      }
    }
  });

  testWidgets('each load failure uses its corresponding localized copy', (
    tester,
  ) async {
    for (final failure in OverviewLoadFailure.values) {
      await _pump(tester, failure: failure);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(BullCarousel)),
      );
      final title = switch (failure) {
        OverviewLoadFailure.balancesMayBeStale => l10n.walletBalancesMayBeStale,
        OverviewLoadFailure.loadFailed => l10n.walletLoadFailed,
        OverviewLoadFailure.cannotDeleteDefaultWallet =>
          l10n.walletDeletionErrorDefaultWallet,
        OverviewLoadFailure.cannotDeleteWithOngoingSwaps =>
          l10n.walletDeletionErrorOngoingSwaps,
        OverviewLoadFailure.walletNotFound =>
          l10n.walletDeletionErrorWalletNotFound,
        OverviewLoadFailure.unexpected => l10n.oopsSomethingWentWrong,
      };
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('no warnings and no backup leave the carousel absent', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(BullCarousel), findsNothing);
    expect(find.byType(BackupCard), findsNothing);
  });

  testWidgets('a sync failure reports stale balances', (tester) async {
    await _pump(tester, failure: OverviewLoadFailure.balancesMayBeStale);

    expect(find.textContaining('may be out of date'), findsOneWidget);
    expect(find.textContaining('could not be loaded'), findsNothing);
  });

  testWidgets('a sync failure and a server warning are both swipeable', (
    tester,
  ) async {
    await _pump(
      tester,
      network: [_bitcoinDown],
      failure: OverviewLoadFailure.balancesMayBeStale,
    );

    final l10n = AppLocalizations.of(tester.element(find.byType(BullCarousel)));
    final serverCard = find.text(l10n.walletWarningElectrumBitcoinDown);
    final syncCard = find.text(l10n.walletBalancesMayBeStale);
    final screen = tester.getRect(find.byType(BullCarousel));
    expect(screen.overlaps(tester.getRect(serverCard)), isTrue);
    expect(screen.overlaps(tester.getRect(syncCard)), isFalse);

    await tester.drag(find.byType(BullCarousel), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(screen.overlaps(tester.getRect(syncCard)), isTrue);
  });

  testWidgets('a failed load is reported with the retry hint', (tester) async {
    await _pump(tester, failure: OverviewLoadFailure.loadFailed);

    final l10n = AppLocalizations.of(tester.element(find.byType(BullCarousel)));
    expect(find.text(l10n.walletLoadFailed), findsOneWidget);
    expect(find.text(l10n.walletLoadFailedRetryHint), findsOneWidget);
  });

  testWidgets(
    'network, swap and load stay ordered with a separate backup action',
    (tester) async {
      final destinations = <HomeWarningDestination>[];
      var backupOpens = 0;
      await _pump(
        tester,
        network: [_bitcoinDown, _torDown],
        failure: OverviewLoadFailure.loadFailed,
        swapDown: true,
        onBackup: () => backupOpens++,
        onOpen: destinations.add,
      );
      final carousel = tester.widget<BullCarousel>(find.byType(BullCarousel));
      final cards = carousel.children
          .cast<ConstrainedBox>()
          .map((box) => box.child as BullInfoCard)
          .toList();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(BullCarousel)),
      );
      expect(cards.map((card) => card.title), [
        l10n.walletWarningElectrumBitcoinDown,
        l10n.torSettingsExternalProxyUnavailable,
        l10n.walletWarningSwapServerUnreachable,
        l10n.walletLoadFailed,
      ]);
      expect(cards.map((card) => card.description), [
        l10n.walletWarningElectrumAction,
        l10n.torSettingsExternalProxyUnavailableDescription,
        l10n.walletWarningSwapServerAction,
        l10n.walletLoadFailedRetryHint,
      ]);
      expect(cards.map((card) => card.onTap != null), [
        true,
        true,
        true,
        false,
      ]);
      for (final card in cards) {
        card.onTap?.call();
      }
      expect(destinations, [
        HomeWarningDestination.electrum,
        HomeWarningDestination.tor,
        HomeWarningDestination.swap,
      ]);
      final backup = find.byType(BackupCard);
      expect(backup, findsOneWidget);
      expect(
        find.descendant(of: find.byType(BullCarousel), matching: backup),
        findsNothing,
      );
      tester.widget<BackupCard>(backup).onTap();
      expect(backupOpens, 1);
    },
  );

  testWidgets('both Electrum chains and Liquid alone have distinct copy', (
    tester,
  ) async {
    for (final reason in [ElectrumServerDown.liquid, ElectrumServerDown.both]) {
      await _pump(
        tester,
        network: [
          WalletWarning(
            reason: reason,
            action: WalletWarningAction.electrumSettings,
            type: WarningType.error,
          ),
        ],
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(BullCarousel)),
      );
      final title = reason == ElectrumServerDown.liquid
          ? l10n.walletWarningElectrumLiquidDown
          : l10n.walletWarningElectrumBothDown;
      expect(find.text(title), findsOneWidget);
      expect(find.text(l10n.walletWarningElectrumAction), findsOneWidget);
    }
  });
}
