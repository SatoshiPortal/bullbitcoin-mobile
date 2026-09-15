import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/clear_exchange_session_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_account_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_announcements_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/request_exchange_account_deletion_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/save_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/store_exchange_api_key_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// What the repository boundary already sanitized it to: a type name, no
/// payload. If a use-case ever widened this, the assertions below would catch
/// it.
const _sanitized = 'getUserSummary failed: DioException';

class _MockUserRepository extends Mock implements ExchangeUserRepository {}

class _MockApiKeyRepository extends Mock implements ExchangeApiKeyRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSendSupportChat extends Mock
    implements SendSupportChatMessageUsecase {}

SettingsEntity _settings(Environment environment) => SettingsEntity(
  environment: environment,
  bitcoinUnit: BitcoinUnit.btc,
  currencyCode: 'CAD',
);

void main() {
  late _MockUserRepository mainnetUsers;
  late _MockUserRepository testnetUsers;
  late _MockApiKeyRepository apiKeys;
  late _MockSettingsRepository settings;

  setUp(() {
    mainnetUsers = _MockUserRepository();
    testnetUsers = _MockUserRepository();
    apiKeys = _MockApiKeyRepository();
    settings = _MockSettingsRepository();
    when(
      settings.fetch,
    ).thenAnswer((_) async => _settings(Environment.mainnet));
  });

  group('GetExchangeAccountUsecase', () {
    GetExchangeAccountUsecase build() => GetExchangeAccountUsecase(
      mainnetExchangeUserRepository: mainnetUsers,
      testnetExchangeUserRepository: testnetUsers,
      settingsRepository: settings,
    );

    test('a repository failure is lifted into the feature family', () async {
      when(mainnetUsers.getUserSummary).thenAnswer(
        (_) async =>
            const Err(ExchangeUserSummaryUnavailableFailure(_sanitized)),
      );

      final failure =
          (await build().execute() as Err).failure as ExchangeFailure;

      expect(failure, isA<ExchangeAccountUnavailableFailure>());
      expect(
        failure,
        isNot(isA<ExchangeUserFailure>()),
        reason: 'the core family must not escape into the cubit',
      );
      expect(failure.logMessage, _sanitized);
    });

    // "No session" is a different user story from "the call failed": one says
    // log in, the other says retry.
    test('not-authenticated keeps its own meaning', () async {
      when(mainnetUsers.getUserSummary).thenAnswer(
        (_) async => const Err(ExchangeUserNotAuthenticatedFailure()),
      );

      final failure =
          (await build().execute() as Err).failure as ExchangeFailure;

      expect(failure, isA<ExchangeNotAuthenticatedFailure>());
    });

    test('a success is forwarded', () async {
      when(mainnetUsers.getUserSummary).thenAnswer(
        (_) async => const Ok(
          UserSummary(
            userNumber: 1,
            groups: [],
            profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
            email: 'sat@example.com',
            balances: [],
            dca: UserDca(isActive: false),
            autoBuy: UserAutoBuy(
              isActive: false,
              addresses: UserAutoBuyAddresses(),
            ),
          ),
        ),
      );

      expect(await build().execute(), isA<Ok<UserSummary, ExchangeFailure>>());
    });

    // A sanitized failure is no good if it came from the wrong network.
    test('testnet settings route to the testnet repository', () async {
      when(
        settings.fetch,
      ).thenAnswer((_) async => _settings(Environment.testnet));
      when(testnetUsers.getUserSummary).thenAnswer(
        (_) async => const Err(ExchangeUserSummaryUnavailableFailure()),
      );

      expect(await build().execute(), isA<Err<UserSummary, ExchangeFailure>>());
      verify(testnetUsers.getUserSummary).called(1);
      verifyNever(mainnetUsers.getUserSummary);
    });
  });

  group('StoreExchangeApiKeyUsecase', () {
    test('an api-key failure is lifted into the feature family', () async {
      when(
        () => apiKeys.saveApiKey(any(), isTestnet: any(named: 'isTestnet')),
      ).thenAnswer(
        (_) async => const Err(ExchangeApiKeySaveFailure('store failed: Type')),
      );

      final result = await StoreExchangeApiKeyUsecase(
        exchangeApiKeyRepository: apiKeys,
        settingsRepository: settings,
      ).execute({'apiKey': 'bbk_live_7f3a9c2e'});
      final failure = (result as Err).failure as ExchangeFailure;

      expect(failure, isA<ExchangeApiKeyStorageFailure>());
      expect(
        failure,
        isNot(isA<ExchangeApiKeyFailure>()),
        reason: 'the core family must not escape into the cubit',
      );
      expect(
        failure.logMessage,
        isNot(contains('bbk_live_7f3a9c2e')),
        reason: 'the key itself must never travel in a failure',
      );
    });
  });

  group('SaveExchangePreferencesUsecase', () {
    test('a repository failure is lifted into the feature family', () async {
      when(
        () => mainnetUsers.saveUserPreference(
          language: any(named: 'language'),
          currency: any(named: 'currency'),
          dcaEnabled: any(named: 'dcaEnabled'),
          autoBuyEnabled: any(named: 'autoBuyEnabled'),
          emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
        ),
      ).thenAnswer(
        (_) async => const Err(ExchangeUserPreferencesSaveFailure('nope')),
      );

      final result = await SaveExchangePreferencesUsecase(
        mainnetExchangeUserRepository: mainnetUsers,
        testnetExchangeUserRepository: testnetUsers,
        settingsRepository: settings,
      ).execute(language: 'en');

      expect((result as Err).failure, isA<ExchangePreferencesSaveFailure>());
    });
  });

  group('GetExchangeAnnouncementsUsecase', () {
    GetExchangeAnnouncementsUsecase build() => GetExchangeAnnouncementsUsecase(
      mainnetExchangeUserRepository: mainnetUsers,
      testnetExchangeUserRepository: testnetUsers,
      settingsRepository: settings,
    );

    test('a repository failure is lifted into the feature family', () async {
      when(mainnetUsers.listAnnouncements).thenAnswer(
        (_) async => const Err(ExchangeUserAnnouncementsUnavailableFailure()),
      );

      expect(
        (await build().execute() as Err).failure,
        isA<ExchangeAnnouncementsUnavailableFailure>(),
      );
    });

    test('a successful load is forwarded', () async {
      when(
        mainnetUsers.listAnnouncements,
      ).thenAnswer((_) async => const Ok(<Announcement>[]));

      expect(
        await build().execute(),
        isA<Ok<List<Announcement>, ExchangeFailure>>(),
      );
    });
  });

  group('ClearExchangeSessionUsecase', () {
    ClearExchangeSessionUsecase build(Future<void> Function() clearCookies) =>
        ClearExchangeSessionUsecase(
          exchangeApiKeyRepository: apiKeys,
          settingsRepository: settings,
          clearCookies: clearCookies,
        );

    test('cookies are still cleared when key deletion fails', () async {
      when(
        () => apiKeys.deleteApiKey(isTestnet: any(named: 'isTestnet')),
      ).thenAnswer((_) async => const Err(ExchangeApiKeyDeleteFailure('nope')));
      var cleared = false;

      final result = await build(() async => cleared = true).execute();

      expect(
        cleared,
        isTrue,
        reason: 'leaving cookies behind after sign-out is the worse outcome',
      );
      expect((result as Err).failure, isA<ExchangeSessionClearFailure>());
    });

    // The cookie manager is a platform call with no repository beneath it, so
    // this use-case is legitimately its boundary.
    test('a throwing cookie clear is caught and sanitized', () async {
      when(
        () => apiKeys.deleteApiKey(isTestnet: any(named: 'isTestnet')),
      ).thenAnswer((_) async => const Ok(null));

      final result = await build(
        () async => throw Exception('PlatformException: bbk_live_7f3a9c2e'),
      ).execute();
      final failure = (result as Err).failure as ExchangeFailure;

      expect(failure, isA<ExchangeSessionClearFailure>());
      expect(failure.logMessage, isNot(contains('bbk_live_7f3a9c2e')));
    });

    test('both succeeding is Ok', () async {
      when(
        () => apiKeys.deleteApiKey(isTestnet: any(named: 'isTestnet')),
      ).thenAnswer((_) async => const Ok(null));

      expect(
        await build(() async {}).execute(),
        isA<Ok<void, ExchangeFailure>>(),
      );
    });
  });

  group('RequestExchangeAccountDeletionUsecase', () {
    late _MockSendSupportChat sendSupportChat;

    setUp(() => sendSupportChat = _MockSendSupportChat());

    test('a support-chat failure is lifted into this family', () async {
      when(
        () => sendSupportChat.execute(
          text: any(named: 'text'),
          attachments: any(named: 'attachments'),
        ),
      ).thenAnswer((_) async => const Err(SendMessageFailure('nope')));

      final result = await RequestExchangeAccountDeletionUsecase(
        sendSupportChatMessageUsecase: sendSupportChat,
      ).execute();
      final failure = (result as Err).failure as ExchangeFailure;

      expect(failure, isA<ExchangeAccountDeletionRequestFailure>());
      expect(
        failure,
        isNot(isA<ExchangeSupportChatFailure>()),
        reason: 'the support-chat family must not escape the use-case',
      );
    });

    test('a sent request is Ok', () async {
      when(
        () => sendSupportChat.execute(
          text: any(named: 'text'),
          attachments: any(named: 'attachments'),
        ),
      ).thenAnswer((_) async => const Ok(null));

      expect(
        await RequestExchangeAccountDeletionUsecase(
          sendSupportChatMessageUsecase: sendSupportChat,
        ).execute(),
        isA<Ok<void, ExchangeFailure>>(),
      );
    });
  });
}
