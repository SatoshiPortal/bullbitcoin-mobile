import 'dart:async';

import 'package:bb_mobile/features/exchange/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_access_repository.dart';
import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_announcements_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/request_exchange_account_deletion_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/save_exchange_preferences_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The failure an [Err] carries, typed by the [Result]; an [Ok] fails the test.
F _failureOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok() => fail('expected an Err, got Ok'),
  Err(:final failure) => failure,
};

class _MockUserRepository extends Mock implements ExchangeUserRepository {}

class _MockAccess extends Mock implements ExchangeAccessRepository {}

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
  late _MockSettingsRepository settings;
  late _MockAccess access;

  setUp(() {
    mainnetUsers = _MockUserRepository();
    testnetUsers = _MockUserRepository();
    settings = _MockSettingsRepository();
    access = _MockAccess();
    when(
      () => access.current,
    ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    when(() => access.epoch).thenReturn(1);
    when(
      settings.fetch,
    ).thenAnswer((_) async => _settings(Environment.mainnet));
  });

  // SettingsRepository is shared core and still throws. These use-cases
  // promise a Result and the cubit has no catch left, so a throw here would
  // escape as an unhandled exception and leave the screen waiting.
  group('a throwing settings read is returned, not thrown', () {
    const reason = 'settings fetch failed: _Exception';

    setUp(() {
      when(settings.fetch).thenThrow(Exception('database is locked'));
    });

    test('SaveExchangePreferencesUsecase', () async {
      final failure = _failureOf(
        await SaveExchangePreferencesUsecase(
          mainnetExchangeUserRepository: mainnetUsers,
          testnetExchangeUserRepository: testnetUsers,
          settingsRepository: settings,
          access: access,
        ).execute(language: 'en'),
      );

      expect(failure, isA<ExchangePreferencesSaveFailure>());
      expect(failure.logMessage, reason);
    });

    test('GetExchangeAnnouncementsUsecase', () async {
      final failure = _failureOf(
        await GetExchangeAnnouncementsUsecase(
          mainnetExchangeUserRepository: mainnetUsers,
          testnetExchangeUserRepository: testnetUsers,
          settingsRepository: settings,
          access: access,
        ).execute(),
      );

      expect(failure, isA<ExchangeAnnouncementsUnavailableFailure>());
      expect(failure.logMessage, reason);
    });
  });

  group('SaveExchangePreferencesUsecase', () {
    // An account whose stored preferences all differ from the test inputs,
    // so a field surviving or being overwritten is always distinguishable.
    const summary = UserSummary(
      userNumber: 1,
      groups: [],
      profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
      email: 'sat@example.com',
      balances: [],
      language: 'en',
      currency: 'CAD',
      dca: UserDca(isActive: true),
      autoBuy: UserAutoBuy(isActive: true, addresses: UserAutoBuyAddresses()),
    );

    SaveExchangePreferencesUsecase build() => SaveExchangePreferencesUsecase(
      mainnetExchangeUserRepository: mainnetUsers,
      testnetExchangeUserRepository: testnetUsers,
      settingsRepository: settings,
      access: access,
    );

    test('a repository failure is lifted into the feature family', () async {
      when(
        mainnetUsers.getUserSummary,
      ).thenAnswer((_) async => const Ok(summary));
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

      final result = await build().execute(language: 'en');

      expect(_failureOf(result), isA<ExchangePreferencesSaveFailure>());
    });

    // The exchange replaces the whole stored set, so every field the caller
    // leaves out must be carried over from a fresh summary.
    test('fields the caller leaves out are filled from a fresh '
        'summary', () async {
      when(
        mainnetUsers.getUserSummary,
      ).thenAnswer((_) async => const Ok(summary));
      when(
        () => mainnetUsers.saveUserPreference(
          language: any(named: 'language'),
          currency: any(named: 'currency'),
          dcaEnabled: any(named: 'dcaEnabled'),
          autoBuyEnabled: any(named: 'autoBuyEnabled'),
          emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
        ),
      ).thenAnswer((_) async => const Ok(null));

      final result = await build().execute(currency: 'EUR');

      expect(result, isA<Ok<void, ExchangeFailure>>());
      verify(
        () => mainnetUsers.saveUserPreference(
          language: 'en',
          currency: 'EUR',
          dcaEnabled: true,
          autoBuyEnabled: 'true',
          emailNotificationsEnabled: true,
        ),
      ).called(1);
    });

    test('a failed summary read aborts the write', () async {
      when(mainnetUsers.getUserSummary).thenAnswer(
        (_) async => const Err(ExchangeUserNetworkFailure('timeout')),
      );

      final result = await build().execute(currency: 'EUR');

      expect(_failureOf(result), isA<ExchangeNetworkFailure>());
      verifyNever(
        () => mainnetUsers.saveUserPreference(
          language: any(named: 'language'),
          currency: any(named: 'currency'),
          dcaEnabled: any(named: 'dcaEnabled'),
          autoBuyEnabled: any(named: 'autoBuyEnabled'),
          emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
        ),
      );
    });
  });

  group('GetExchangeAnnouncementsUsecase', () {
    GetExchangeAnnouncementsUsecase build() => GetExchangeAnnouncementsUsecase(
      mainnetExchangeUserRepository: mainnetUsers,
      testnetExchangeUserRepository: testnetUsers,
      settingsRepository: settings,
      access: access,
    );

    test('a repository failure is lifted into the feature family', () async {
      when(mainnetUsers.listAnnouncements).thenAnswer(
        (_) async => const Err(ExchangeUserAnnouncementsUnavailableFailure()),
      );

      expect(
        _failureOf(await build().execute()),
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

  test('a late announcement failure is stale after an access change', () async {
    var epoch = 1;
    when(() => access.epoch).thenAnswer((_) => epoch);
    final pending =
        Completer<Result<List<Announcement>, ExchangeUserFailure>>();
    when(mainnetUsers.listAnnouncements).thenAnswer((_) => pending.future);
    final operation = GetExchangeAnnouncementsUsecase(
      mainnetExchangeUserRepository: mainnetUsers,
      testnetExchangeUserRepository: testnetUsers,
      settingsRepository: settings,
      access: access,
    ).execute();
    await Future<void>.delayed(Duration.zero);
    epoch++;
    pending.complete(const Err(ExchangeUserAnnouncementsUnavailableFailure()));
    expect(_failureOf(await operation), isA<ExchangeOperationStaleFailure>());
  });

  test('a late summary failure cannot affect a newer session', () async {
    var epoch = 1;
    when(() => access.epoch).thenAnswer((_) => epoch);
    final pending = Completer<Result<UserSummary, ExchangeUserFailure>>();
    when(mainnetUsers.getUserSummary).thenAnswer((_) => pending.future);
    final operation = SaveExchangePreferencesUsecase(
      mainnetExchangeUserRepository: mainnetUsers,
      testnetExchangeUserRepository: testnetUsers,
      settingsRepository: settings,
      access: access,
    ).execute(currency: 'EUR');
    await Future<void>.delayed(Duration.zero);
    epoch++;
    pending.complete(const Err(ExchangeUserNetworkFailure()));
    expect(_failureOf(await operation), isA<ExchangeOperationStaleFailure>());
    verifyNever(
      () => mainnetUsers.saveUserPreference(
        language: any(named: 'language'),
        currency: any(named: 'currency'),
        dcaEnabled: any(named: 'dcaEnabled'),
        autoBuyEnabled: any(named: 'autoBuyEnabled'),
        emailNotificationsEnabled: any(named: 'emailNotificationsEnabled'),
      ),
    );
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
      final failure = _failureOf(result);

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
