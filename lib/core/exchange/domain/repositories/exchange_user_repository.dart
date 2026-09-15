import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

/// The account side of the exchange API. Implementations are the `try/catch`
/// boundary: they log the raw reason and return a sanitized
/// [ExchangeUserFailure].
abstract interface class ExchangeUserRepository {
  @useResult
  Future<Result<UserSummary, ExchangeUserFailure>> getUserSummary();

  @useResult
  Future<Result<void, ExchangeUserFailure>> registerScamWarningConsent();

  @useResult
  Future<Result<void, ExchangeUserFailure>> saveUserPreference({
    String? language,
    String? currency,
    bool? dcaEnabled,
    String? autoBuyEnabled,
    bool? emailNotificationsEnabled,
  });

  @useResult
  Future<Result<List<Announcement>, ExchangeUserFailure>> listAnnouncements();
}
