import 'overview_catalogue.dart';

/// One admitted wallet and the money already produced for it. `balanceSat` is
/// null when no current receipt exists; null never means zero.
typedef OverviewHomeWallet = ({OverviewCatalogueEntry entry, int? balanceSat});

typedef OverviewHomeSnapshot = ({
  OverviewCatalogueStatus status,
  List<OverviewHomeWallet> wallets,
});

/// The read-only Home projection of the Overview catalogue.
///
/// Home never opens, hydrates or syncs a wallet through this port: it copies
/// what the catalogue already holds each time [changes] fires, then republishes
/// its own view state. A row read after a later event may already be retired.
abstract interface class OverviewHomeSource {
  Stream<void> get changes;

  OverviewHomeSnapshot get snapshot;
}
