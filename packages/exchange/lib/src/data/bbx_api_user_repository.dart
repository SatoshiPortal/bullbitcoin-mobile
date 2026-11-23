import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/announcement.dart';
import '../domain/entities/user_summary.dart';
import '../domain/exchange_failure.dart';
import 'bbx_api_user_summary_mapper.dart';

final class BbxApiUserRepository {
  final bbx.Bbx _api;

  const BbxApiUserRepository({required this._api});

  Future<Result<UserSummary, ExchangeFailure>> getUserSummary() async {
    try {
      final result = await _api.users.getUserSummary();
      return switch (result) {
        Ok(value: final summary?) => Ok(userSummaryFromBbxApi(summary)),
        Ok() => _emptySummary(),
        Err(failure: final bbx.BbxRpcFailure failure) => _refusedSummary(
          failure,
        ),
        Err(:final failure) => Err(
          _failureFrom(
            failure,
            StackTrace.current,
            'getUserSummary',
            ExchangeAccountUnavailableFailure.new,
          ),
        ),
      };
    } catch (e, st) {
      return Err(
        _unexpected(
          e,
          st,
          'getUserSummary',
          ExchangeAccountUnavailableFailure.new,
        ),
      );
    }
  }

  Result<UserSummary, ExchangeFailure> _emptySummary() {
    // A key that resolves to no account is an auth problem, not transport.
    log.warning('Exchange user summary came back empty');
    return const Err(ExchangeNotAuthenticatedFailure());
  }

  Result<UserSummary, ExchangeFailure> _refusedSummary(
    bbx.BbxRpcFailure failure,
  ) {
    // The old client read an error reply as no account.
    log.warning(
      'Exchange user summary refused: ${failure.code}${failure.requestIdLabel}',
    );
    return const Err(ExchangeNotAuthenticatedFailure());
  }

  Future<Result<void, ExchangeFailure>> registerScamWarningConsent() async {
    try {
      final result = await _api.users.registerResponsibilityConsent();
      switch (result) {
        case Ok(value: true):
          return const Ok(null);
        case Ok():
          return const Err(ExchangeConsentRegistrationFailure());
        case Err(:final failure):
          return Err(
            _failureFrom(
              failure,
              StackTrace.current,
              'registerResponsibilityConsent',
              ExchangeConsentRegistrationFailure.new,
            ),
          );
      }
    } catch (e, st) {
      return Err(
        _unexpected(
          e,
          st,
          'registerResponsibilityConsent',
          ExchangeConsentRegistrationFailure.new,
        ),
      );
    }
  }

  Future<Result<void, ExchangeFailure>> saveUserPreference({
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
      Err(failure: bbx.BbxOutcomeUnknownFailure(:final reason)) => Err(
        ExchangePreferencesSaveOutcomeUnknownFailure(
          'saveUserPreference outcome unknown: $reason',
        ),
      ),
      Err(:final failure) => Err(
        _failureFrom(
          failure,
          StackTrace.current,
          'saveUserPreference',
          ExchangePreferencesSaveFailure.new,
        ),
      ),
    };
  }

  Future<Result<List<Announcement>, ExchangeFailure>>
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
            ExchangeAnnouncementsUnavailableFailure.new,
          ),
        ),
      };
    } catch (e, st) {
      return Err(
        _unexpected(
          e,
          st,
          'listAnnouncements',
          ExchangeAnnouncementsUnavailableFailure.new,
        ),
      );
    }
  }

  ExchangeFailure _failureFrom(
    bbx.BbxFailure failure,
    StackTrace st,
    String operation,
    ExchangeFailure Function([String?]) onFailure,
  ) {
    switch (failure) {
      case bbx.BbxMissingCredentialFailure():
        return const ExchangeNotAuthenticatedFailure();
      case bbx.BbxCredentialUnavailableFailure():
        return const ExchangeCredentialReadFailure();
      case bbx.BbxTimeoutFailure(:final kind):
        final reason = switch (kind) {
          bbx.BbxTimeoutKind.connect => 'connectionTimeout',
          bbx.BbxTimeoutKind.send => 'sendTimeout',
          bbx.BbxTimeoutKind.receive => 'receiveTimeout',
        };
        log.warning('Could not reach the exchange API to $operation: $reason');
        return ExchangeNetworkFailure('$operation unreachable: $reason');
      case bbx.BbxConnectionFailure():
        log.warning(
          'Could not reach the exchange API to $operation: connectionError',
        );
        return ExchangeNetworkFailure(
          '$operation unreachable: connectionError',
        );
      default:
        final description =
            '$operation failed: ${failure.runtimeType}${failure.requestIdLabel}';
        log.warning(description, trace: st);
        return onFailure(description);
    }
  }

  ExchangeFailure _unexpected(
    Object e,
    StackTrace st,
    String operation,
    ExchangeFailure Function([String?]) onFailure,
  ) {
    if (e is Error) Error.throwWithStackTrace(e, st);
    log.warning('$operation failed: ${e.runtimeType}', trace: st);
    return onFailure('$operation failed: ${e.runtimeType}');
  }
}
