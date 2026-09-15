import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
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
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;
  final bool _isTestnet;

  ExchangeUserRepositoryImpl({
    required this._bullbitcoinApiDatasource,
    required this._bullbitcoinApiKeyDatasource,
    required this._isTestnet,
  });

  @override
  Future<Result<UserSummary, ExchangeUserFailure>> getUserSummary() async {
    try {
      final apiKey = await _apiKey();
      if (apiKey == null) {
        return const Err(ExchangeUserNotAuthenticatedFailure());
      }

      final userSummaryModel = await _bullbitcoinApiDatasource.getUserSummary(
        apiKey,
      );
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
      final apiKey = await _apiKey();
      if (apiKey == null) {
        return const Err(ExchangeUserNotAuthenticatedFailure());
      }

      await _bullbitcoinApiDatasource.registerResponsibilityConsent(apiKey);
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
      final apiKey = await _apiKey();
      if (apiKey == null) {
        return const Err(ExchangeUserNotAuthenticatedFailure());
      }

      await _bullbitcoinApiDatasource.saveUserPreference(
        apiKey: apiKey,
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
      final apiKey = await _apiKey();
      if (apiKey == null) {
        // Signed out is not a failure here: there is simply nothing to show.
        return const Ok([]);
      }

      final announcementDataList = await _bullbitcoinApiDatasource
          .listAnnouncements(apiKey: apiKey);

      return Ok(
        announcementDataList
            .map((json) => AnnouncementModel.fromJson(json).toEntity())
            .toList(),
      );
    } catch (e, st) {
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
  /// A `dart:core` [Error] is a bug and goes to Sentry as `severe`. Anything
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
    if (e is DioException && _isUnreachable(e.type)) {
      log.warning(
        'Could not reach the exchange API to $operation: ${e.type.name}',
      );
      return ExchangeUserNetworkFailure(
        '$operation unreachable: ${e.type.name}',
      );
    }
    if (e is Error) {
      log.severe(message: '$operation failed', error: e.runtimeType, trace: st);
    } else {
      log.warning('$operation failed: ${e.runtimeType}', trace: st);
    }
    return onFailure('$operation failed: ${e.runtimeType}');
  }

  bool _isUnreachable(DioExceptionType type) => switch (type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    _ => false,
  };

  Future<String?> _apiKey() async {
    final apiKey = await _bullbitcoinApiKeyDatasource.get(
      isTestnet: _isTestnet,
    );
    return apiKey?.key;
  }
}
