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
