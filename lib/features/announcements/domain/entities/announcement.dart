/// A home-screen announcement: a dismissible, tappable nudge shown in the
/// wallet-home carousel (e.g. "Increase privacy with Payjoin").
///
/// Announcements are defined in code (compile-time), not persisted — only the
/// per-user *dismissal* fact is stored (see `DismissedAnnouncements` table).
/// The user-facing title/description are NOT held here: they map to
/// localization keys in the presentation layer so `domain/` stays Flutter-free.
library;

/// Stable identifier for each announcement. The enum *name* is the persistence
/// key (stored in `dismissed_announcements.announcement_id`) and the l10n key
/// prefix, so **never rename or reorder existing values** — only append.
enum AnnouncementId {
  /// Shown once the wallet has transaction history and payjoin is disabled,
  /// inviting the user to enable payjoin for better on-chain privacy.
  payjoinPrivacy,

}

/// Visual/semantic tone of an announcement, mapped to theme colors in the UI.
enum AnnouncementTone { info, warning, success }

/// What tapping the announcement's body does.
sealed class AnnouncementAction {
  const AnnouncementAction();
}

/// Tapping the announcement navigates somewhere. The concrete destination is
/// resolved in the ui layer (`ui/announcement_navigation.dart`) from the
/// [Announcement]'s id, so `domain/` never imports another feature's router.
final class NavigateAction extends AnnouncementAction {
  const NavigateAction();
}

/// How re-display works after the user dismisses an announcement.
sealed class DismissPolicy {
  const DismissPolicy();
}

/// Once dismissed, never shown again (until its trigger condition itself
/// changes — which is decided by the trigger, not this policy).
final class PermanentDismiss extends DismissPolicy {
  const PermanentDismiss();
}

/// Dismissed only temporarily: re-arms (becomes eligible again) once [interval]
/// has elapsed since the dismissal timestamp.
final class SnoozeDismiss extends DismissPolicy {
  final Duration interval;

  SnoozeDismiss(this.interval) {
    if (interval.inMicroseconds <= 0) {
      throw ArgumentError.value(
        interval,
        'interval',
        'snooze interval must be positive',
      );
    }
  }
}

/// A rich, self-validating announcement definition.
///
/// Invalid instances are impossible to construct: the id is a closed enum, the
/// action and policy are sealed, and [priority] is validated in the
/// constructor. Ordering in the carousel is by ascending [priority].
class Announcement {
  final AnnouncementId id;

  /// Lower shows first in the carousel. Must be non-negative.
  final int priority;

  final AnnouncementTone tone;
  final AnnouncementAction action;
  final DismissPolicy dismissPolicy;

  Announcement({
    required this.id,
    required this.priority,
    required this.tone,
    required this.action,
    required this.dismissPolicy,
  }) {
    if (priority < 0) {
      throw ArgumentError.value(priority, 'priority', 'must be non-negative');
    }
  }

  /// Whether a dismissal recorded at [dismissedAt] still suppresses this
  /// announcement as of [now]. Permanent dismissals always suppress; snooze
  /// dismissals stop suppressing once the interval has elapsed.
  bool isSuppressedBy(DateTime dismissedAt, {required DateTime now}) {
    return switch (dismissPolicy) {
      PermanentDismiss() => true,
      SnoozeDismiss(:final interval) => now.isBefore(dismissedAt.add(interval)),
    };
  }
}
