import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement_catalog.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';

/// Orchestrates which announcements are currently visible on the home carousel.
///
/// Thin orchestration only: it gathers the trigger signals (payjoin setting,
/// whether the wallet has transaction history), asks each catalog entry whether
/// its trigger fires, drops anything the user has dismissed (respecting the
/// per-announcement dismiss policy), and returns the survivors ordered by
/// ascending priority. All decision *rules* live on the entities / catalog;
/// this use-case only wires signals to them.
class GetVisibleAnnouncementsUsecase {
  final SettingsRepository _settingsRepository;
  final GetWalletTransactionsUsecase _getWalletTransactionsUsecase;
  final GetAutoSwapSettingsUsecase _getAutoSwapSettingsUsecase;
  final AnnouncementDismissalRepository _dismissalRepository;

  GetVisibleAnnouncementsUsecase({
    required this._settingsRepository,
    required this._getWalletTransactionsUsecase,
    required this._getAutoSwapSettingsUsecase,
    required this._dismissalRepository,
  });

  Future<Result<List<Announcement>, AnnouncementsFailure>> execute() async {
    try {
      // The four sources are independent, so gather them concurrently.
      final (settings, transactions, autoSwap, dismissals) = await (
        _settingsRepository.fetch(),
        _getWalletTransactionsUsecase.execute(),
        _getAutoSwapSettingsUsecase.execute(),
        _dismissalRepository.getDismissals(),
      ).wait;

      final signals = AnnouncementSignals(
        isPayjoinEnabled: settings.isPayjoinEnabled,
        hasTransactionHistory: transactions.isNotEmpty,
        isAutoswapEnabled: autoSwap.enabled,
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
      // Sources span settings/tx/autoswap/storage, so this is a genuine
      // catch-all rather than a storage-only failure.
      return Err(AnnouncementUnexpectedFailure(e.toString()));
    }
  }
}
