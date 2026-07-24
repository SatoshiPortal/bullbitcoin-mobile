import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Announcement build({required DismissPolicy policy, int priority = 0}) {
    return Announcement(
      id: AnnouncementId.payjoinPrivacy,
      priority: priority,
      tone: AnnouncementTone.info,
      action: const NavigateAction(),
      dismissPolicy: policy,
    );
  }

  group('Announcement invariants', () {
    test('rejects a negative priority', () {
      expect(
        () => build(policy: const PermanentDismiss(), priority: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('SnoozeDismiss rejects a non-positive interval', () {
      expect(
        () => SnoozeDismiss(const Duration(microseconds: 0)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('isSuppressedBy', () {
    final now = DateTime(2026, 7, 20, 12);

    test('permanent policy always suppresses, regardless of age', () {
      final a = build(policy: const PermanentDismiss());
      final longAgo = now.subtract(const Duration(days: 3650));
      expect(a.isSuppressedBy(longAgo, now: now), isTrue);
    });

    test('snooze policy still suppresses before the interval elapses', () {
      final a = build(policy: SnoozeDismiss(const Duration(days: 90)));
      final dismissedAt = now.subtract(const Duration(days: 30));
      expect(a.isSuppressedBy(dismissedAt, now: now), isTrue);
    });

    test('snooze policy re-arms once the interval elapses', () {
      final a = build(policy: SnoozeDismiss(const Duration(days: 90)));
      final dismissedAt = now.subtract(const Duration(days: 91));
      expect(a.isSuppressedBy(dismissedAt, now: now), isFalse);
    });
  });
}
