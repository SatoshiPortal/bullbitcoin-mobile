import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/delete_exchange_account_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_account_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_announcements_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/save_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_access_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_notifications_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Account extends Mock implements GetExchangeAccountUsecase {}

class _Preferences extends Mock implements SaveExchangePreferencesUsecase {}

class _Announcements extends Mock implements GetExchangeAnnouncementsUsecase {}

class _Delete extends Mock implements DeleteExchangeAccountUsecase {}

class _WatchAccess extends Mock implements WatchExchangeAccessUsecase {}

class _Notifications extends Mock
    implements WatchExchangeNotificationsUsecase {}

const account = UserSummary(
  userNumber: 1,
  groups: [],
  profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

void main() {
  late _Account getAccount;
  late _Preferences preferences;
  late _Announcements announcements;
  late _Delete deletion;
  late _WatchAccess watchAccess;
  late _Notifications notifications;
  late StreamController<ExchangeAccess> changes;

  void publish(ExchangeAccess access) {
    when(() => watchAccess.current).thenReturn(access);
    changes.add(access);
  }

  ExchangeCubit build() => ExchangeCubit(
    getExchangeAccountUsecase: getAccount,
    saveExchangePreferencesUsecase: preferences,
    getExchangeAnnouncementsUsecase: announcements,
    deleteAccount: deletion,
    watchAccess: watchAccess,
    watchExchangeNotificationsUsecase: notifications,
  );

  setUp(() {
    getAccount = _Account();
    preferences = _Preferences();
    announcements = _Announcements();
    deletion = _Delete();
    watchAccess = _WatchAccess();
    when(() => watchAccess.current).thenReturn(const ExchangeAccessDisabled());
    notifications = _Notifications();
    changes = StreamController<ExchangeAccess>.broadcast(sync: true);
    when(watchAccess.execute).thenAnswer((_) => changes.stream);
    when(notifications.accountChanges).thenAnswer((_) => const Stream.empty());
    when(getAccount.execute).thenAnswer((_) async => const Ok(account));
    when(announcements.execute).thenAnswer((_) async => const Ok([]));
    addTearDown(changes.close);
  });

  test(
    'signed in access loads the account; disabled access clears it',
    () async {
      final cubit = build();
      addTearDown(cubit.close);
      publish(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.userSummary, account);
      publish(const ExchangeAccessDisabled());
      expect(cubit.state.userSummary, isNull);
    },
  );

  test('deletion failure is forwarded by the account use case', () async {
    when(deletion.execute).thenAnswer(
      (_) async => const Err(ExchangeAccountDeletionRequestFailure()),
    );
    final cubit = build();
    addTearDown(cubit.close);
    expect(
      (await cubit.deleteAccount() as Err).failure,
      isA<ExchangeAccountDeletionRequestFailure>(),
    );
    verify(deletion.execute).called(1);
  });

  test('a stale account response is not shown after access changes', () async {
    final pending = Completer<Result<UserSummary, ExchangeFailure>>();
    when(getAccount.execute).thenAnswer((_) => pending.future);
    final cubit = build();
    addTearDown(cubit.close);
    publish(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    publish(const ExchangeAccessDisabled());
    pending.complete(const Err(ExchangeOperationStaleFailure()));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.userSummary, isNull);
    expect(cubit.state.getUserSummaryFailure, isNull);
  });

  test('a late account success cannot restore a disabled session', () async {
    final pending = Completer<Result<UserSummary, ExchangeFailure>>();
    when(getAccount.execute).thenAnswer((_) => pending.future);
    final cubit = build();
    addTearDown(cubit.close);
    publish(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    publish(const ExchangeAccessDisabled());
    pending.complete(const Ok(account));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.userSummary, isNull);
  });

  test('a late older refresh cannot restore an active DCA', () async {
    final first = Completer<Result<UserSummary, ExchangeFailure>>();
    final second = Completer<Result<UserSummary, ExchangeFailure>>();
    var calls = 0;
    when(
      getAccount.execute,
    ).thenAnswer((_) => ++calls == 1 ? first.future : second.future);
    final cubit = build();
    addTearDown(cubit.close);
    publish(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    final newest = cubit.fetchUserSummary();
    second.complete(const Ok(account));
    await newest;
    first.complete(Ok(account.copyWith(dca: const UserDca(isActive: true))));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.userSummary, account);
    expect(cubit.state.userSummary?.dca.isActive, isFalse);
  });

  test('a late older failure cannot replace a successful refresh', () async {
    final first = Completer<Result<UserSummary, ExchangeFailure>>();
    final second = Completer<Result<UserSummary, ExchangeFailure>>();
    var calls = 0;
    when(
      getAccount.execute,
    ).thenAnswer((_) => ++calls == 1 ? first.future : second.future);
    final cubit = build();
    addTearDown(cubit.close);
    publish(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    final newest = cubit.fetchUserSummary();
    second.complete(const Ok(account));
    await newest;
    first.complete(const Err(ExchangeNetworkFailure()));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.userSummary, account);
    expect(cubit.state.getUserSummaryFailure, isNull);
  });

  test('a late older success cannot erase a newer refresh failure', () async {
    final first = Completer<Result<UserSummary, ExchangeFailure>>();
    final second = Completer<Result<UserSummary, ExchangeFailure>>();
    var calls = 0;
    when(
      getAccount.execute,
    ).thenAnswer((_) => ++calls == 1 ? first.future : second.future);
    final cubit = build();
    addTearDown(cubit.close);
    publish(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    final newest = cubit.fetchUserSummary();
    second.complete(const Err(ExchangeNetworkFailure()));
    await newest;
    first.complete(const Ok(account));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.userSummary, isNull);
    expect(cubit.state.getUserSummaryFailure, isA<ExchangeNetworkFailure>());
  });

  test(
    'retry clears an initial error while the new request is pending',
    () async {
      final retry = Completer<Result<UserSummary, ExchangeFailure>>();
      var calls = 0;
      when(getAccount.execute).thenAnswer(
        (_) => ++calls == 1
            ? Future.value(const Err(ExchangeNetworkFailure()))
            : retry.future,
      );
      final cubit = build();
      addTearDown(cubit.close);
      publish(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.getUserSummaryFailure, isA<ExchangeNetworkFailure>());
      expect(cubit.state.isFetchingUserSummary, isFalse);

      final pending = cubit.fetchUserSummary();
      expect(cubit.state.getUserSummaryFailure, isNull);
      expect(cubit.state.isFetchingUserSummary, isTrue);
      retry.complete(const Ok(account));
      await pending;
      expect(cubit.state.userSummary, account);
      expect(cubit.state.getUserSummaryFailure, isNull);
      expect(cubit.state.isFetchingUserSummary, isFalse);
    },
  );

  test(
    'retry retains a previously loaded account and reports a new failure',
    () async {
      final retry = Completer<Result<UserSummary, ExchangeFailure>>();
      var calls = 0;
      when(getAccount.execute).thenAnswer((_) {
        calls++;
        if (calls == 1) return Future.value(const Ok(account));
        if (calls == 2) {
          return Future.value(const Err(ExchangeNetworkFailure()));
        }
        return retry.future;
      });
      final cubit = build();
      addTearDown(cubit.close);
      publish(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
      await Future<void>.delayed(Duration.zero);
      await cubit.fetchUserSummary();
      expect(cubit.state.getUserSummaryFailure, isA<ExchangeNetworkFailure>());
      final pending = cubit.fetchUserSummary();
      expect(cubit.state.userSummary, account);
      expect(cubit.state.getUserSummaryFailure, isNull);
      retry.complete(const Err(ExchangeAccountUnavailableFailure()));
      await pending;
      expect(cubit.state.userSummary, account);
      expect(
        cubit.state.getUserSummaryFailure,
        isA<ExchangeAccountUnavailableFailure>(),
      );
    },
  );

  test('stop DCA reports a preference failure', () async {
    when(
      () => preferences.execute(dcaEnabled: false),
    ).thenAnswer((_) async => const Err(ExchangeNetworkFailure()));
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.stopDca();
    expect(cubit.state.stopDcaFailure, isA<ExchangeNetworkFailure>());
    expect(cubit.state.isSaving, isFalse);
  });
}
