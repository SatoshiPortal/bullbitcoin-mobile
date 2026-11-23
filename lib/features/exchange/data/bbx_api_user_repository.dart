import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_user_summary_mapper.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// [ExchangeUserRepository] through the `bbx_api` package.
///
/// Failures are logged by type only before a sanitized [ExchangeUserFailure]
/// travels on.
class BbxApiUserRepository implements ExchangeUserRepository {
  final bbx.Bbx _api;

  BbxApiUserRepository({required this._api});

  @override
  Future<Result<UserSummary, ExchangeUserFailure>> getUserSummary() async {
    try {
      final result = await _api.users.getUserSummary();
      return switch (result) {
        Ok(value: final summary?) => Ok(userSummaryFromBbxApi(summary)),
        Ok() => _emptySummary(),
        Err(failure: bbx.BbxRpcFailure(:final code)) => _refusedSummary(code),
        Err(:final failure) => Err(
          _failureFrom(
            failure,
            StackTrace.current,
            'getUserSummary',
            ExchangeUserSummaryUnavailableFailure.new,
          ),
        ),
      };
    } catch (e, st) {
      return Err(
        _unexpected(
          e,
          st,
          'getUserSummary',
          ExchangeUserSummaryUnavailableFailure.new,
        ),
      );
    }
  }

  Result<UserSummary, ExchangeUserFailure> _emptySummary() {
    // A key that resolves to no account is an auth problem, not transport.
    log.warning('Exchange user summary came back empty');
    return const Err(ExchangeUserNotAuthenticatedFailure());
  }

  Result<UserSummary, ExchangeUserFailure> _refusedSummary(int? code) {
    // The old client read an error reply as no account.
    log.warning('Exchange user summary refused: $code');
    return const Err(ExchangeUserNotAuthenticatedFailure());
  }

  @override
  Future<Result<void, ExchangeUserFailure>> registerScamWarningConsent() async {
    try {
      final result = await _api.users.registerResponsibilityConsent();
      switch (result) {
        case Ok(value: true):
          return const Ok(null);
        case Ok():
          throw const _ConsentNotRecorded();
        case Err(:final failure):
          return Err(
            _failureFrom(
              failure,
              StackTrace.current,
              'registerResponsibilityConsent',
              ExchangeUserConsentRegistrationFailure.new,
            ),
          );
      }
    } catch (e, st) {
      return Err(
        _unexpected(
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
    final result = await _api.users.saveUserPreferences(
      bbx.UserPreferences(
        language: language,
        defaultFiatCurrencyCode: currency,
        dcaEnabled: dcaEnabled?.toString(),
        autoBuyEnabled: autoBuyEnabled,
        emailNotifications: emailNotificationsEnabled?.toString(),
      ),
    );
    return switch (result) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(
        _failureFrom(
          failure,
          StackTrace.current,
          'saveUserPreference',
          ExchangeUserPreferencesSaveFailure.new,
        ),
      ),
    };
  }

  @override
  Future<Result<List<Announcement>, ExchangeUserFailure>>
  listAnnouncements() async {
    try {
      final result = await _api.commcenter.listAnnouncements();
      return switch (result) {
        Ok(:final value) => Ok([
          for (final a in value)
            Announcement(
              title: a.title,
              description: a.description,
              updatedAt: a.updatedAt,
            ),
        ]),
        Err(failure: bbx.BbxMissingCredentialFailure()) => const Ok([]),
        Err(:final failure) => Err(
          _failureFrom(
            failure,
            StackTrace.current,
            'listAnnouncements',
            ExchangeUserAnnouncementsUnavailableFailure.new,
          ),
        ),
      };
    } catch (e, st) {
      return Err(
        _unexpected(
          e,
          st,
          'listAnnouncements',
          ExchangeUserAnnouncementsUnavailableFailure.new,
        ),
      );
    }
  }

  ExchangeUserFailure _failureFrom(
    bbx.BbxFailure failure,
    StackTrace st,
    String operation,
    ExchangeUserFailure Function([String?]) onFailure,
  ) {
    switch (failure) {
      case bbx.BbxMissingCredentialFailure():
        return const ExchangeUserNotAuthenticatedFailure();
      case bbx.BbxCredentialUnavailableFailure():
        return const ExchangeUserCredentialUnavailableFailure();
      case bbx.BbxTimeoutFailure(:final kind):
        final reason = switch (kind) {
          bbx.BbxTimeoutKind.connect => 'connectionTimeout',
          bbx.BbxTimeoutKind.send => 'sendTimeout',
          bbx.BbxTimeoutKind.receive => 'receiveTimeout',
        };
        log.warning('Could not reach the exchange API to $operation: $reason');
        return ExchangeUserNetworkFailure('$operation unreachable: $reason');
      case bbx.BbxConnectionFailure():
        log.warning(
          'Could not reach the exchange API to $operation: connectionError',
        );
        return ExchangeUserNetworkFailure(
          '$operation unreachable: connectionError',
        );
      default:
        log.warning('$operation failed: ${failure.runtimeType}', trace: st);
        return onFailure('$operation failed: ${failure.runtimeType}');
    }
  }

  ExchangeUserFailure _unexpected(
    Object e,
    StackTrace st,
    String operation,
    ExchangeUserFailure Function([String?]) onFailure,
  ) {
    if (e is Error) Error.throwWithStackTrace(e, st);
    log.warning('$operation failed: ${e.runtimeType}', trace: st);
    return onFailure('$operation failed: ${e.runtimeType}');
  }
}

/// The server answered without `success: true`.
final class _ConsentNotRecorded implements Exception {
  const _ConsentNotRecorded();
}
