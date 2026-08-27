import 'package:bb_mobile/features/announcements/data/mappers/announcement_dismissal_mapper.dart';
import 'package:bb_mobile/features/announcements/data/models/announcement_dismissal_model.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnnouncementDismissalMapper.toEntity', () {
    test('maps a known id to the domain entity', () {
      final dismissedAt = DateTime.utc(2026, 7, 20, 12);
      final model = AnnouncementDismissalModel(
        announcementId: AnnouncementId.payjoinPrivacy.name,
        dismissedAt: dismissedAt,
      );

      final entity = model.toEntity();

      expect(entity, isNotNull);
      expect(entity!.id, AnnouncementId.payjoinPrivacy);
      expect(entity.dismissedAt, dismissedAt);
    });

    test('returns null for an unknown id (forward-compat downgrade)', () {
      final model = AnnouncementDismissalModel(
        announcementId: 'someAnnouncementFromANewerBuild',
        dismissedAt: DateTime.utc(2026),
      );

      expect(model.toEntity(), isNull);
    });
  });
}
