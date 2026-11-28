import '../domain/overview_catalogue.dart';
import '../domain/overview_home_source.dart';

/// Projects the mounted catalogue onto Home's read-only view.
///
/// The catalogue stays the owner of membership and receipts: this adapter only
/// copies the snapshot Home would have read anyway, and every later catalogue
/// event brings a fresh copy. Home can explicitly retry incomplete membership.
final class CatalogueHomeSource
    implements OverviewHomeSource, OverviewHomeMembershipRetry {
  final OverviewCatalogue _catalogue;

  const CatalogueHomeSource(this._catalogue);

  @override
  Stream<void> get changes => _catalogue.changes;

  @override
  void retryMembership() => _catalogue.retryMembership();

  @override
  OverviewHomeSnapshot get snapshot {
    final current = _catalogue.snapshot;
    return (
      status: current.status,
      wallets: [
        for (final row in current.rows)
          (entry: row.entry, balanceSat: row.balanceSat?.toInt()),
      ],
    );
  }
}
