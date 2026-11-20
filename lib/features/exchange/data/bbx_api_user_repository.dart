import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_user_summary_mapper.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';

/// [ExchangeUserRepository] through the `bbx_api` package.
///
/// The `try/catch` boundary: the raw reason is logged by type only and a
/// sanitized [ExchangeUserFailure] travels on.
class BbxApiUserRepository implements ExchangeUserRepository {
  final bbx.BbxApiClient _api;

  BbxApiUserRepository({required this._api});

  @override
  Future<Result<UserSummary, ExchangeUserFailure>> getUserSummary() async {
    try {
      final summary = await _api.users.getUserSummary();
      if (summary == null) {
        // A key that resolves to no account is an auth problem, not transport.
        log.warning('Exchange user summary came back empty');
        return const Err(ExchangeUserNotAuthenticatedFailure());
      }
      return Ok(userSummaryFromBbxApi(summary));
    } on bbx.BbxApiRpcException catch (e) {
      // The old client read an error reply as no account.
      log.warning('Exchange user summary refused: ${e.code}');
      return const Err(ExchangeUserNotAuthenticatedFailure());
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
      if (!await _api.users.registerResponsibilityConsent()) {
        throw const _ConsentNotRecorded();
      }
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
      await _api.users.saveUserPreferences(
        bbx.UserPreferences(
          language: language,
          defaultFiatCurrencyCode: currency,
          dcaEnabled: dcaEnabled?.toString(),
          autoBuyEnabled: autoBuyEnabled,
          emailNotifications: emailNotificationsEnabled?.toString(),
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
      return Ok([
        for (final a in await _api.commcenter.listAnnouncements())
          Announcement(
            title: a.title,
            description: a.description,
            updatedAt: a.updatedAt,
          ),
      ]);
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
  /// A `dart:core` [Error] is a bug and propagates. Anything else is logged
  /// as a `warning`. Unreachable is told apart because it is the one case
  /// with advice the user can act on.
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
          : const ExchangeUserCredentialUnavailableFailure();
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

/// The server answered without `success: true`.
final class _ConsentNotRecorded implements Exception {
  const _ConsentNotRecorded();
}
