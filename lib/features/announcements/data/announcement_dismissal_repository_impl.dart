import 'package:bb_mobile/features/announcements/data/datasources/announcement_dismissal_datasource.dart';
import 'package:bb_mobile/features/announcements/data/mappers/announcement_dismissal_mapper.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement_dismissal.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';

class AnnouncementDismissalRepositoryImpl
    implements AnnouncementDismissalRepository {
  final AnnouncementDismissalDatasource _datasource;

  AnnouncementDismissalRepositoryImpl({required this._datasource});

  @override
  Future<List<AnnouncementDismissal>> getDismissals() async {
    final models = await _datasource.fetchAll();
    // Drop rows whose id is unknown to this build (forward-compat downgrade).
    return models
        .map((m) => m.toEntity())
        .whereType<AnnouncementDismissal>()
        .toList();
  }

  @override
  Future<void> dismiss(AnnouncementId id) async {
    // Persist in UTC, per the `dismissed_announcements.dismissedAt` contract.
    await _datasource.upsert(id.name, DateTime.now().toUtc());
  }
}
