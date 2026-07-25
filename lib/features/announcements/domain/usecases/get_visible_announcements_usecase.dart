import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement_catalog.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';

/// Orchestrates which announcements are currently visible on the home carousel.
///
/// Thin orchestration only: it gathers the trigger signals (autoswap settings
/// and the Liquid balance they apply to), asks each catalog entry whether its
/// trigger fires, drops anything the user has dismissed (respecting the
/// per-announcement dismiss policy), and returns the survivors ordered by
/// ascending priority. All decision *rules* live on the entities / catalog;
/// this use-case only wires signals to them.
class GetVisibleAnnouncementsUsecase {
  final GetWalletsUsecase _getWalletsUsecase;
  final GetAutoSwapSettingsUsecase _getAutoSwapSettingsUsecase;
  final AnnouncementDismissalRepository _dismissalRepository;

  GetVisibleAnnouncementsUsecase({
    required this._getWalletsUsecase,
    required this._getAutoSwapSettingsUsecase,
    required this._dismissalRepository,
  });

  Future<Result<List<Announcement>, AnnouncementsFailure>> execute() async {
    try {
      // The three sources are independent, so gather them concurrently.
      final (liquidWallets, autoSwap, dismissals) = await (
        _getWalletsUsecase.execute(onlyLiquid: true, onlyDefaults: true),
        _getAutoSwapSettingsUsecase.execute(),
        _dismissalRepository.getDismissals(),
      ).wait;

      // Autoswap sweeps the default Liquid wallet, so its balance is what
      // the trigger threshold applies to. The threshold rule itself lives on
      // the AutoSwap entity (passedRequiredBalance also checks `enabled`).
      final liquidBalanceSat = liquidWallets.fold<BigInt>(
        BigInt.zero,
        (sum, w) => sum + w.balanceSat,
      );
      final signals = AnnouncementSignals(
        isAutoswapTriggerable: autoSwap.passedRequiredBalance(
          liquidBalanceSat.toInt(),
        ),
      );

      final dismissedAtById = {for (final d in dismissals) d.id: d.dismissedAt};
      final now = DateTime.now().toUtc();

      final visible = <Announcement>[];
      for (final entry in announcementCatalog) {
        if (!entry.triggersFor(signals)) continue;

        final dismissedAt = dismissedAtById[entry.announcement.id];
        final suppressed =
            dismissedAt != null &&
            entry.announcement.isSuppressedBy(dismissedAt, now: now);
        if (suppressed) continue;

        visible.add(entry.announcement);
      }

      visible.sort((a, b) => a.priority.compareTo(b.priority));
      return Ok(visible);
    } catch (e) {
      // Sources span wallets/autoswap/storage, so this is a genuine
      // catch-all rather than a storage-only failure.
      return Err(AnnouncementUnexpectedFailure(e.toString()));
    }
  }
}
