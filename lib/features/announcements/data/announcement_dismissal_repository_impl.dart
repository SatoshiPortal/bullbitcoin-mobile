import 'package:bb_mobile/features/announcements/data/models/announcement_dismissal_model.dart';
import 'package:preferences/preferences.dart' show AnnouncementDismissals;
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/announcements/data/mappers/announcement_dismissal_mapper.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement_dismissal.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';

class AnnouncementDismissalRepositoryImpl
    implements AnnouncementDismissalRepository {
  final AnnouncementDismissals _dismissals;

  AnnouncementDismissalRepositoryImpl({required this._dismissals});

  @override
  Future<List<AnnouncementDismissal>> getDismissals() async {
    final records = (await _dismissals.read()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    );
    // Drop rows whose id is unknown to this build (forward-compat downgrade).
    return records
        .map(
          (record) => AnnouncementDismissalModel(
            announcementId: record.id,
            dismissedAt: record.dismissedAt,
          ).toEntity(),
        )
        .whereType<AnnouncementDismissal>()
        .toList();
  }

  @override
  Future<void> dismiss(AnnouncementId id) async {
    // Persist in UTC, per the `dismissed_announcements.dismissedAt` contract.
    final result = await _dismissals.dismiss(id.name, DateTime.now().toUtc());
    if (result case Err()) {
      throw Exception('Could not persist announcement dismissal');
    }
  }
}
