import 'package:material_ui/material_ui.dart';

import '../../domain/home_network_warnings.dart';
import '../../domain/overview_load_failure.dart';
import 'home_warning_carousel.dart';

typedef HomeWarningsCopy = ({
  String bitcoinDown,
  String liquidDown,
  String bothDown,
  String electrumAction,
  HomeWarningCopy tor,
  HomeWarningCopy swap,
  String balancesMayBeStale,
  String loadFailed,
  String cannotDeleteDefaultWallet,
  String cannotDeleteWithOngoingSwaps,
  String walletNotFound,
  String unexpected,
  String retryHint,
});

class OverviewHomeWarnings extends StatelessWidget {
  final List<WalletWarning> network;
  final bool swapServerUnreachable;
  final OverviewLoadFailure? loadFailure;
  final HomeWarningsCopy copy;
  final Widget? backup;
  final ValueChanged<HomeWarningDestination> onOpen;

  const OverviewHomeWarnings({
    super.key,
    required this.network,
    required this.swapServerUnreachable,
    required this.loadFailure,
    required this.copy,
    required this.backup,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final failure = loadFailure;
    return HomeWarningCarousel(
      network: [
        for (final warning in network)
          switch (warning.action) {
            WalletWarningAction.torSettings => (
              copy: copy.tor,
              destination: HomeWarningDestination.tor,
            ),
            WalletWarningAction.electrumSettings => (
              copy: (
                title: switch (warning.reason) {
                  ElectrumServerDown.bitcoin => copy.bitcoinDown,
                  ElectrumServerDown.liquid => copy.liquidDown,
                  ElectrumServerDown.both => copy.bothDown,
                },
                description: copy.electrumAction,
              ),
              destination: HomeWarningDestination.electrum,
            ),
          },
      ],
      swap: swapServerUnreachable ? copy.swap : null,
      load: failure == null
          ? null
          : (title: _failureTitle(failure), description: copy.retryHint),
      backup: backup,
      onOpen: onOpen,
    );
  }

  String _failureTitle(OverviewLoadFailure failure) => switch (failure) {
    OverviewLoadFailure.balancesMayBeStale => copy.balancesMayBeStale,
    OverviewLoadFailure.loadFailed => copy.loadFailed,
    OverviewLoadFailure.cannotDeleteDefaultWallet =>
      copy.cannotDeleteDefaultWallet,
    OverviewLoadFailure.cannotDeleteWithOngoingSwaps =>
      copy.cannotDeleteWithOngoingSwaps,
    OverviewLoadFailure.walletNotFound => copy.walletNotFound,
    OverviewLoadFailure.unexpected => copy.unexpected,
  };
}
