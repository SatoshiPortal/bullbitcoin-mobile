import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:bull_exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Account extends Mock implements GetExchangeAccountUsecase {}

class _Preferences extends Mock implements SaveExchangePreferencesUsecase {}

class _Announcements extends Mock implements GetExchangeAnnouncementsUsecase {}

/// The access source the cubit reads: the current value and its changes.
abstract interface class _AccessSource {
  ExchangeAccess get current;
  Stream<ExchangeAccess> execute();
}

class _WatchAccess extends Mock implements _AccessSource {}

class _Authentication extends Mock
    implements CompleteExchangeAuthenticationUsecase {}

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
  late _WatchAccess watchAccess;
  late _Notifications notifications;
  late StreamController<ExchangeAccess> changes;

  void publish(ExchangeAccess access) {
    when(() => watchAccess.current).thenReturn(access);
    changes.add(access);
  }

  ExchangeCubit build() => ExchangeCubit(
    getAccount: getAccount.execute,
    getAnnouncements: announcements.execute,
    stopDca: () => preferences.execute(dcaEnabled: false),
    currentAccess: () => watchAccess.current,
    accessChanges: watchAccess.execute(),
    accountChanges: notifications.accountChanges(),
    connectNotifications: ({required reconnect}) =>
        reconnect ? notifications.reconnect() : notifications.connect(),
    disconnectNotifications: notifications.disconnect,
  );

  setUp(() {
    getAccount = _Account();
    preferences = _Preferences();
    announcements = _Announcements();
    watchAccess = _WatchAccess();
    when(() => watchAccess.current).thenReturn(const ExchangeAccessDisabled());
    notifications = _Notifications();
    changes = StreamController<ExchangeAccess>.broadcast(sync: true);
    when(watchAccess.execute).thenAnswer((_) => changes.stream);
    when(notifications.accountChanges).thenAnswer((_) => const Stream.empty());
    when(getAccount.execute).thenAnswer((_) async => const Ok(account));
    when(announcements.execute).thenAnswer((_) async => const Ok([]));
    when(notifications.connect).thenAnswer((_) async => const Ok(null));
    addTearDown(changes.close);
  });

  test('each signed-in reconciliation reopens notifications for an unchanged account', () async {
    final cubit = build();
    addTearDown(cubit.close);
    publish(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.userSummary, account);
    verify(notifications.connect).called(1);

    // Reconciliation disconnects and emits signed in again; the account
    // summary is unchanged, so no summary transition can reopen the socket.
    publish(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.userSummary, account);
    verify(notifications.connect).called(1);
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

  test('authentication loads the account only when it succeeds', () async {
    final authentication = _Authentication();
    var outcome = const Err<void, ExchangeFailure>(
      ExchangeAuthenticationFailure(),
    ) as Result<void, ExchangeFailure>;
    when(() => authentication.execute(isCurrent: any(named: 'isCurrent')))
        .thenAnswer((_) async => outcome);
    final cubit = build();
    addTearDown(cubit.close);
    when(
      () => watchAccess.current,
    ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));

    final failed = await cubit.completeAuthentication(
      authentication.execute,
      isCurrent: () => true,
    );
    expect(failed, isA<Err<void, ExchangeFailure>>());
    verifyNever(getAccount.execute);

    outcome = const Ok(null);
    final saved = await cubit.completeAuthentication(
      authentication.execute,
      isCurrent: () => true,
    );
    expect(saved, isA<Ok<void, ExchangeFailure>>());
    expect(cubit.state.userSummary, account);
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
    when(getAccount.execute)
        .thenAnswer((_) => ++calls == 1 ? first.future : second.future);
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
    when(getAccount.execute)
        .thenAnswer((_) => ++calls == 1 ? first.future : second.future);
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
    when(getAccount.execute)
        .thenAnswer((_) => ++calls == 1 ? first.future : second.future);
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
    when(() => preferences.execute(dcaEnabled: false))
        .thenAnswer((_) async => const Err(ExchangeNetworkFailure()));
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.stopDca();
    expect(cubit.state.stopDcaFailure, isA<ExchangeNetworkFailure>());
    expect(cubit.state.isSaving, isFalse);
  });
}
