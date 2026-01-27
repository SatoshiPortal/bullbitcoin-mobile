import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';

abstract class ExchangeUserRepository {
  Future<UserSummary?> getUserSummary();
  Future<void> saveUserPreference({
    String? language,
    String? currency,
    bool? dcaEnabled,
    String? autoBuyEnabled,
    bool? emailNotificationsEnabled,
  });
  Future<List<Announcement>> listAnnouncements();
}
