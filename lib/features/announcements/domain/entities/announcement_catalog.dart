import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';

/// The runtime signals a trigger can read to decide whether it fires.
///
/// Extend this (and the gathering in `GetVisibleAnnouncementsUsecase`) as new
/// announcements need new signals.
class AnnouncementSignals {
  final bool isPayjoinEnabled;
  final bool hasTransactionHistory;
  final bool isAutoswapEnabled;

  const AnnouncementSignals({
    required this.isPayjoinEnabled,
    required this.hasTransactionHistory,
    required this.isAutoswapEnabled,
  });
}

/// A catalog entry: an [Announcement] definition paired with the predicate that
/// decides whether it should appear given the current [AnnouncementSignals].
class AnnouncementCatalogEntry {
  final Announcement announcement;

  /// Predicate deciding whether this announcement should appear given the
  /// current signals. Read through [triggersFor].
  final bool Function(AnnouncementSignals signals) trigger;

  const AnnouncementCatalogEntry({
    required this.announcement,
    required this.trigger,
  });

  bool triggersFor(AnnouncementSignals signals) => trigger(signals);
}

/// The single compile-time registry of every home announcement.
///
/// To add an announcement: append an [AnnouncementId] value, add a catalog
/// entry here with its trigger, and add the title/description l10n mapping in
/// `presentation/announcement_l10n.dart`.
final List<AnnouncementCatalogEntry> announcementCatalog = [
  AnnouncementCatalogEntry(
    announcement: Announcement(
      id: AnnouncementId.payjoinPrivacy,
      priority: 0,
      tone: AnnouncementTone.info,
      action: NavigateAction(SettingsRoute.payjoinSettings.name),
      dismissPolicy: const PermanentDismiss(),
    ),
    // Show once the wallet has received/transacted (first UTXO or history after
    // create/recover) AND payjoin is still off — nudging the privacy upgrade.
    trigger: (s) => s.hasTransactionHistory && !s.isPayjoinEnabled,
  ),
  AnnouncementCatalogEntry(
    announcement: Announcement(
      id: AnnouncementId.autoswapActive,
      priority: 1,
      tone: AnnouncementTone.success,
      action: NavigateAction(SettingsRoute.autoswapSettings.name),
      dismissPolicy: const PermanentDismiss(),
    ),
    // Show while autoswap is enabled, letting the user learn what it does.
    trigger: (s) => s.isAutoswapEnabled,
  ),
];
