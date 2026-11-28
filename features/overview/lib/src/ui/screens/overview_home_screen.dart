import 'package:material_ui/material_ui.dart';
import 'package:swap_feature/swap_feature.dart' show HomeOngoingSwaps;

import '../../domain/overview_catalogue.dart';
import '../../presentation/overview_home_controller.dart';
import '../../presentation/overview_home_state.dart';
import '../widgets/home_warning_carousel.dart' show HomeWarningDestination;
import '../widgets/home_warnings.dart';
import '../widgets/wallet_home_top_section.dart';
import '../widgets/wallet_picker.dart';
import 'overview_home.dart';

/// Builds the pinned header from Home's own display facts. The caller owns the
/// artwork, quick actions, chart and currency callback, so Overview stays free
/// of settings and onboarding.
typedef OverviewHomeHeaderBuilder = Widget Function(
  BuildContext context, {
  required int? totalSat,
  required bool isLoading,
  required bool? hideAmounts,
});

/// The public Home screen: existing Overview rows, warnings and shell, wired to
/// one [OverviewHomeController].
///
/// Composition only. Every journey, copy string and artwork is supplied by the
/// composition root through a narrow slot; this screen never routes, reads a
/// preference store or imports another feature's internals.
class OverviewHomeScreen extends StatelessWidget {
  final OverviewHomeController controller;

  /// The route location that counts as "Home visible" for the automatic
  /// refresh trigger.
  final String homePath;
  final OverviewHomeHeaderBuilder header;
  final Widget announcements;

  /// The Send owner's consolidation banner. Overview does not build it.
  final Widget consolidation;

  /// Onboarding, shown only when the catalogue genuinely holds no wallet.
  final Widget? empty;

  /// Built by the caller (RecoverBull owns the artwork and route); rendered
  /// only while the controller reports a needed backup.
  final Widget backupWarning;
  final Widget Function(int refresh, String arkScope) ark;
  final Widget bottomActions;

  final WalletPickerCopy walletPickerCopy;
  final HomeWarningsCopy warningsCopy;

  final ValueChanged<OverviewWalletSelection> onOpenWallet;
  final ValueChanged<HomeWarningDestination> onOpenWarning;

  /// The Silent card is independent of wallet selection. Without this callback
  /// the card is not offered at all.
  final VoidCallback? onOpenSilent;

  const OverviewHomeScreen({
    super.key,
    required this.controller,
    required this.homePath,
    required this.header,
    required this.announcements,
    required this.consolidation,
    required this.empty,
    required this.backupWarning,
    required this.ark,
    required this.bottomActions,
    required this.walletPickerCopy,
    required this.warningsCopy,
    required this.onOpenWallet,
    required this.onOpenWarning,
    required this.onOpenSilent,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OverviewHomeState>(
      valueListenable: controller.state,
      builder: (context, state, _) {
        final openSilent = onOpenSilent;
        return OverviewHome(
          homePath: homePath,
          empty: state.isEmpty ? empty : null,
          // A stale "no wallets" must never turn an automatic round into a
          // pull on the onboarding slot.
          isRefreshing: !state.isEmpty && state.isRefreshing,
          refreshVisibleWallets: controller.refreshVisible,
          waitForRefresh: controller.waitForRefresh,
          refreshWallets: controller.refresh,
          headerBackgroundHeight: WalletHomeTopSection.minBackgroundHeight,
          header: header(
            context,
            totalSat: state.totalSat,
            isLoading: state.isLoading,
            hideAmounts: state.hideAmounts,
          ),
          announcements: announcements,
          warnings: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeOngoingSwaps(swaps: state.ongoingSwaps),
              OverviewHomeWarnings(
                network: state.networkWarnings,
                swapServerUnreachable: state.swapServerUnreachable,
                loadFailure: state.loadFailure,
                copy: warningsCopy,
                backup: state.backupCard ? backupWarning : null,
                onOpen: onOpenWarning,
              ),
            ],
          ),
          consolidation: consolidation,
          wallets: WalletPicker(
            rows: state.rows,
            copy: walletPickerCopy,
            silent: state.showSilentCard && openSilent != null
                ? (
                    balanceSat: state.silent.balanceSat,
                    isSyncing: state.silent.loading,
                    onOpen: openSilent,
                  )
                : null,
            onSelected: onOpenWallet,
          ),
          ark: (refresh) => ark(refresh, state.arkScope),
          bottomActions: bottomActions,
        );
      },
    );
  }
}
