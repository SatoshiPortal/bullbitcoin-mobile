import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/clear_exchange_session_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_account_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_announcements_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/request_exchange_account_deletion_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/save_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/store_exchange_api_key_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_notifications_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _account = UserSummary(
  userNumber: 1,
  groups: [],
  profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

class _MockGetAccount extends Mock implements GetExchangeAccountUsecase {}

class _MockStoreApiKey extends Mock implements StoreExchangeApiKeyUsecase {}

class _MockSavePreferences extends Mock
    implements SaveExchangePreferencesUsecase {}

class _MockClearSession extends Mock implements ClearExchangeSessionUsecase {}

class _MockGetAnnouncements extends Mock
    implements GetExchangeAnnouncementsUsecase {}

class _MockRequestDeletion extends Mock
    implements RequestExchangeAccountDeletionUsecase {}

class _MockWatchNotifications extends Mock
    implements WatchExchangeNotificationsUsecase {}

void main() {
  late _MockClearSession clearSession;
  late _MockGetAccount getAccount;
  late _MockRequestDeletion requestDeletion;
  late _MockWatchNotifications notifications;
  late _MockGetAnnouncements announcements;
  late _MockSavePreferences savePreferences;

  ExchangeCubit build() => ExchangeCubit(
    getExchangeAccountUsecase: getAccount,
    storeExchangeApiKeyUsecase: _MockStoreApiKey(),
    saveExchangePreferencesUsecase: savePreferences,
    clearExchangeSessionUsecase: clearSession,
    getExchangeAnnouncementsUsecase: announcements,
    requestExchangeAccountDeletionUsecase: requestDeletion,
    watchExchangeNotificationsUsecase: notifications,
  );

  setUp(() {
    clearSession = _MockClearSession();
    getAccount = _MockGetAccount();
    requestDeletion = _MockRequestDeletion();
    notifications = _MockWatchNotifications();
    announcements = _MockGetAnnouncements();
    savePreferences = _MockSavePreferences();
    when(
      announcements.execute,
    ).thenAnswer((_) async => const Ok(<Announcement>[]));

    when(notifications.accountChanges).thenAnswer((_) => const Stream.empty());
    when(notifications.connect).thenAnswer((_) async => const Ok(null));
    when(notifications.disconnect).thenReturn(null);
    when(getAccount.execute).thenAnswer((_) async => const Ok(_account));
  });

  group('logout', () {
    test('a cleared session signs the user out', () async {
      when(clearSession.execute).thenAnswer((_) async => const Ok(null));
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.fetchUserSummary();

      final failure = await cubit.logout();

      expect(failure, isNull);
      expect(cubit.state.userSummary, isNull);
      expect(cubit.state.logoutFailure, isNull);
    });

    // Every failure belonged to the session that ended; one surviving would
    // re-show its banner to whoever signs in next.
    test('a clean sign-out leaves no failure behind', () async {
      when(clearSession.execute).thenAnswer((_) async => const Ok(null));
      when(() => savePreferences.execute(dcaEnabled: false)).thenAnswer(
        (_) async => const Err(ExchangePreferencesSaveFailure('nope')),
      );
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.stopDca();
      expect(cubit.state.stopDcaFailure, isNotNull);

      await cubit.logout();

      expect(cubit.state.stopDcaFailure, isNull);
      expect(cubit.state.getUserSummaryFailure, isNull);
      expect(cubit.state.savePreferencesFailure, isNull);
      expect(cubit.state.saveApiKeyFailure, isNull);
      expect(cubit.state.logoutFailure, isNull);
    });

    // The security-relevant case: if the stored key survives, a signed-out UI
    // is a lie — the next fetch would sign the user straight back in.
    test('a failed clear does NOT present the user as signed out', () async {
      when(clearSession.execute).thenAnswer(
        (_) async => const Err(ExchangeSessionClearFailure('keychain locked')),
      );
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.fetchUserSummary();
      expect(cubit.state.userSummary, isNotNull);

      final failure = await cubit.logout();

      expect(failure, isA<ExchangeSessionClearFailure>());
      expect(
        cubit.state.userSummary,
        isNotNull,
        reason: 'the session is still live, so the UI must not claim otherwise',
      );
      expect(cubit.state.logoutFailure, isA<ExchangeSessionClearFailure>());
    });

    test('a failed clear restores the notification socket', () async {
      when(
        clearSession.execute,
      ).thenAnswer((_) async => const Err(ExchangeSessionClearFailure()));
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.logout();

      verify(notifications.disconnect).called(greaterThanOrEqualTo(1));
      verify(notifications.connect).called(greaterThanOrEqualTo(1));
    });
  });

  group('deleteAccount', () {
    test('a failed request is reported and nothing is cleared', () async {
      when(requestDeletion.execute).thenAnswer(
        (_) async => const Err(ExchangeAccountDeletionRequestFailure('nope')),
      );
      final cubit = build();
      addTearDown(cubit.close);

      expect(
        await cubit.deleteAccount(),
        isA<ExchangeAccountDeletionRequestFailure>(),
      );
      verifyNever(clearSession.execute);
    });

    // The request reached support, but the session survived: confirming
    // success here would tell the user the account is gone from the device.
    test(
      'a sent request with a failed sign-out still reports a failure',
      () async {
        when(requestDeletion.execute).thenAnswer((_) async => const Ok(null));
        when(clearSession.execute).thenAnswer(
          (_) async =>
              const Err(ExchangeSessionClearFailure('keychain locked')),
        );
        final cubit = build();
        addTearDown(cubit.close);

        expect(await cubit.deleteAccount(), isA<ExchangeSessionClearFailure>());
      },
    );

    test('a sent request with a clean sign-out reports success', () async {
      when(requestDeletion.execute).thenAnswer((_) async => const Ok(null));
      when(clearSession.execute).thenAnswer((_) async => const Ok(null));
      final cubit = build();
      addTearDown(cubit.close);

      expect(await cubit.deleteAccount(), isNull);
      expect(cubit.state.userSummary, isNull);
    });
  });
}
