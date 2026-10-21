import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/mappers/user_summary_mapper.dart';
import 'package:bb_mobile/core/exchange/data/models/announcement_model.dart';
import 'package:bb_mobile/core/exchange/data/models/user_preference_payload_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';

/// The `try/catch` boundary for the account side of the exchange API.
///
/// The datasources below throw, and their messages interpolate the raw `'$e'`.
/// Nothing above this class sees that: the reason is logged here and only a
/// sanitized [ExchangeUserFailure] travels on.
class ExchangeUserRepositoryImpl implements ExchangeUserRepository {
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;

  ExchangeUserRepositoryImpl({required this._bullbitcoinApiDatasource});

  @override
  Future<Result<UserSummary, ExchangeUserFailure>> getUserSummary() async {
    try {
      final userSummaryModel = await _bullbitcoinApiDatasource.getUserSummary();
      if (userSummaryModel == null) {
        // A key that resolves to no account is an auth problem, not transport.
        log.warning('Exchange user summary came back empty');
        return const Err(ExchangeUserNotAuthenticatedFailure());
      }

      return Ok(UserSummaryMapper.fromModelToEntity(userSummaryModel));
    } catch (e, st) {
      return Err(
        _failureFrom(
          e,
          st,
          'getUserSummary',
          ExchangeUserSummaryUnavailableFailure.new,
        ),
      );
    }
  }

  @override
  Future<Result<void, ExchangeUserFailure>> registerScamWarningConsent() async {
    try {
      await _bullbitcoinApiDatasource.registerResponsibilityConsent();
      return const Ok(null);
    } catch (e, st) {
      return Err(
        _failureFrom(
          e,
          st,
          'registerResponsibilityConsent',
          ExchangeUserConsentRegistrationFailure.new,
        ),
      );
    }
  }

  @override
  Future<Result<void, ExchangeUserFailure>> saveUserPreference({
    String? language,
    String? currency,
    bool? dcaEnabled,
    String? autoBuyEnabled,
    bool? emailNotificationsEnabled,
  }) async {
    try {
      await _bullbitcoinApiDatasource.saveUserPreference(
        params: UserPreferencePayloadModel(
          language: language,
          currencyCode: currency,
          dcaEnabled: dcaEnabled?.toString(),
          autoBuyEnabled: autoBuyEnabled,
          emailNotificationsEnabled: emailNotificationsEnabled?.toString(),
        ),
      );
      return const Ok(null);
    } catch (e, st) {
      return Err(
        _failureFrom(
          e,
          st,
          'saveUserPreference',
          ExchangeUserPreferencesSaveFailure.new,
        ),
      );
    }
  }

  @override
  Future<Result<List<Announcement>, ExchangeUserFailure>>
  listAnnouncements() async {
    try {
      final announcementDataList = await _bullbitcoinApiDatasource
          .listAnnouncements();

      return Ok(
        announcementDataList
            .map((json) => AnnouncementModel.fromJson(json).toEntity())
            .toList(),
      );
    } catch (e, st) {
      if (exchangeAuthenticationException(e)?.isUnauthenticated ?? false) {
        return const Ok([]);
      }
      return Err(
        _failureFrom(
          e,
          st,
          'listAnnouncements',
          ExchangeUserAnnouncementsUnavailableFailure.new,
        ),
      );
    }
  }

  /// Maps a thrown error to a sanitized failure, logging only its type.
  ///
  /// A `dart:core` [Error] is a bug and propagates. Anything
  /// else (a refused request, a timeout, an offline device) is an ordinary
  /// condition and is logged as a `warning`, so it does not raise a Sentry
  /// event. Unreachable is told apart because it is the one case with advice
  /// the user can act on.
  ExchangeUserFailure _failureFrom(
    Object e,
    StackTrace st,
    String operation,
    ExchangeUserFailure Function([String?]) onFailure,
  ) {
    if (e is Error) Error.throwWithStackTrace(e, st);
    if (e case DioException(error: final Error bug, stackTrace: final trace)) {
      Error.throwWithStackTrace(bug, trace);
    }
    final refusal = exchangeAuthenticationException(e);
    if (refusal != null) {
      return refusal.isUnauthenticated
          ? const ExchangeUserNotAuthenticatedFailure()
          : onFailure('Exchange credential unavailable');
    }
    if (e is DioException && _isUnreachable(e.type)) {
      log.warning(
        'Could not reach the exchange API to $operation: ${e.type.name}',
      );
      return ExchangeUserNetworkFailure(
        '$operation unreachable: ${e.type.name}',
      );
    }
    log.warning('$operation failed: ${e.runtimeType}', trace: st);
    return onFailure('$operation failed: ${e.runtimeType}');
  }

  bool _isUnreachable(DioExceptionType type) => switch (type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    _ => false,
  };
}
