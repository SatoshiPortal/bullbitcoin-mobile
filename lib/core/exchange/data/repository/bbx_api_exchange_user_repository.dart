import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/mappers/bbx_api_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';

/// [ExchangeUserRepository] on the shared `bbx_api` client.
class BbxApiExchangeUserRepository implements ExchangeUserRepository {
  final BbxApiDatasource _api;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;

  BbxApiExchangeUserRepository({
    required this._api,
    required this._apiKeyDatasource,
    required this._isTestnet,
  });

  @override
  Future<Result<UserSummary, ExchangeUserFailure>> getUserSummary() => _guard(
    'getUserSummary',
    ExchangeUserSummaryUnavailableFailure.new,
    () async =>
        BbxApiMapper.userSummary((await _api.users.getUserSummary()).unwrap()),
  );

  @override
  Future<Result<void, ExchangeUserFailure>> registerScamWarningConsent() =>
      _guard(
        'registerResponsibilityConsent',
        ExchangeUserConsentRegistrationFailure.new,
        () async {
          final success = (await _api.users.consentToScamWarning()).unwrap();
          if (!success) {
            throw Exception(
              'Unexpected response from registerResponsibilityConsent',
            );
          }
        },
      );

  @override
  Future<Result<void, ExchangeUserFailure>> saveUserPreference({
    String? language,
    String? currency,
    bool? dcaEnabled,
    bool? autoBuyEnabled,
    bool? emailNotificationsEnabled,
  }) => _guard(
    'saveUserPreference',
    ExchangeUserPreferencesSaveFailure.new,
    () async => (await _api.users.saveUserPreference(
      bbx.UserPreferencePayload(
        language: language,
        currencyCode: currency,
        dcaEnabled: dcaEnabled,
        autoBuyEnabled: autoBuyEnabled,
        emailNotifications: emailNotificationsEnabled,
      ),
    )).unwrap(),
  );

  @override
  Future<Result<List<Announcement>, ExchangeUserFailure>>
  listAnnouncements() async {
    if (await _apiKey() == null) {
      return const Ok([]);
    }
    return _guard(
      'listAnnouncements',
      ExchangeUserAnnouncementsUnavailableFailure.new,
      () async => (await _api.messages.listAnnouncements(
        announcementPayload: bbx.ListRequest(
          payload: bbx.ListAnnouncementsPayload(),
        ),
      )).unwrap().items.map(BbxApiMapper.announcement).toList(),
      checkApiKey: false,
    );
  }

  Future<Result<T, ExchangeUserFailure>> _guard<T>(
    String operation,
    ExchangeUserFailure Function([String?]) onFailure,
    Future<T> Function() call, {
    bool checkApiKey = true,
  }) async {
    try {
      if (checkApiKey && await _apiKey() == null) {
        return const Err(ExchangeUserNotAuthenticatedFailure());
      }
      return Ok(await call());
    } on BbxApiException catch (e) {
      final error = e.error;
      if (error.isApiKeyMissing) {
        return const Err(ExchangeUserNotAuthenticatedFailure());
      }
      if (error.isUnreachable) {
        log.warning(
          'Could not reach the exchange API to $operation: '
          '${error.kind.name}',
        );
        return Err(
          ExchangeUserNetworkFailure(
            '$operation unreachable: ${error.kind.name}',
          ),
        );
      }
      log.warning('$operation failed: $e');
      return Err(onFailure('$operation failed: $e'));
    } catch (e, st) {
      if (e is Error) {
        log.severe(
          message: '$operation failed',
          error: e.runtimeType,
          trace: st,
        );
      } else {
        log.warning('$operation failed: ${e.runtimeType}', trace: st);
      }
      return Err(onFailure('$operation failed: ${e.runtimeType}'));
    }
  }

  Future<String?> _apiKey() async =>
      (await _apiKeyDatasource.get(isTestnet: _isTestnet))?.key;
}
