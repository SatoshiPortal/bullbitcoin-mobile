import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';

/// The runtime signals a trigger can read to decide whether it fires.
///
/// Extend this (and the gathering in `GetVisibleAnnouncementsUsecase`) as new
/// announcements need new signals.
class AnnouncementSignals {
  /// Whether autoswap is enabled AND the Liquid balance has actually reached
  /// its trigger threshold (`AutoSwap.passedRequiredBalance`) — the card
  /// informs about an imminent/behaving swap, so a balance that can't
  /// trigger one shouldn't surface it (product decision 2026-07-25).
  final bool isAutoswapTriggerable;

  const AnnouncementSignals({required this.isAutoswapTriggerable});
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
///
/// The payjoin-privacy nudge was removed on purpose (product decision
/// 2026-07-25): payjoin education lives in the enable-time disclaimer and the
/// payjoin settings screen, not on home. Its [AnnouncementId] value stays so
/// persisted dismissals of it keep mapping cleanly.
final List<AnnouncementCatalogEntry> announcementCatalog = [
  AnnouncementCatalogEntry(
    announcement: Announcement(
      id: AnnouncementId.autoswapActive,
      priority: 0,
      tone: AnnouncementTone.success,
      action: const NavigateAction(),
      dismissPolicy: const PermanentDismiss(),
    ),
    // Show while autoswap is enabled AND the balance can actually trigger a
    // swap, letting the user learn what is about to happen to their funds.
    trigger: (s) => s.isAutoswapTriggerable,
  ),
];
