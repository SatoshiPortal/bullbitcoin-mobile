import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';

abstract class ExchangeUserRepository {
  Future<UserSummary?> getUserSummary();
  Future<void> saveUserPreference({
    String? language,
    String? currency,
    String? dcaEnabled,
    String? autoBuyEnabled,
  });
}
