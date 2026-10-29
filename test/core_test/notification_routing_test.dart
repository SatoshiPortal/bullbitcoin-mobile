import 'dart:async';
import 'dart:io';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/resolve_notification_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/take_permissions_intro_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../features/broadcast_signed_tx/wallet_fixture.dart';

class _Get extends Mock implements GetWalletsUsecase {}

class _Intro extends Fake implements TakePermissionsIntroUsecase {
  @override
  Future<bool> execute() async => false;
}

class _Gateway extends Fake implements LocalNotificationGateway {
  late NotificationResponseCallback response;
  @override
  Future<Result<void, NotificationsFailure>> initialize(
    NotificationResponseCallback onResponse,
  ) async {
    response = onResponse;
    return const Ok(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SqliteNotificationOutbox outbox;
  late NotificationsFacade notifications;
  late _Gateway gateway;
  late _Get get;
  final wallet = publicBroadcastWallet();
  final destination = NotificationDestination.wallet(
    WalletPaymentNotificationIdentity.topicId(
      WalletNetworkKey(wallet.id, 'bitcoin', 'mainnet'),
    ),
  );
  setUp(() async {
    await locator.reset();
    AppRouter.suspendNotificationRouting();
    directory = await Directory.systemTemp.createTemp('notification-routing');
    outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/outbox.sqlite',
    );
    gateway = _Gateway();
    notifications = NotificationsFacade(gateway: gateway, outbox: outbox);
    get = _Get();
    when(() => get.execute()).thenAnswer((_) async => Ok([wallet]));
    locator.registerSingleton<NotificationsFacade>(notifications);
    locator.registerSingleton<ResolveNotificationWalletUsecase>(
      ResolveNotificationWalletUsecase(get: get),
    );
    locator.registerSingleton<TakePermissionsIntroUsecase>(_Intro());
    await notifications.initialize(
      onResponsePersisted: () =>
          unawaited(AppRouter.routePendingNotificationIfUnlocked()),
    );
    AppRouter.router.goNamed(WalletRoute.walletHome.name);
  });
  tearDown(() async {
    AppRouter.suspendNotificationRouting();
    await locator.reset();
    outbox.dispose();
    await directory.delete(recursive: true);
  });
  String getPath() => AppRouter.router.routeInformationProvider.value.uri.path;
  Future<void> tap() async {
    gateway.response(NotificationsFacade.encodeDestination(destination));
    await pumpEventQueue(times: 30);
  }

  test('warm taps open the receiving wallet without a second unlock', () async {
    await AppRouter.routeAfterUnlock();
    await tap();
    expect(getPath(), '/wallet/public-wallet');
    expect(
      (await notifications.consumePendingDestination() as Ok).value,
      isNull,
    );
    await AppRouter.routePendingNotificationIfUnlocked();
    expect(getPath(), '/wallet/public-wallet');
  });
  test(
    'a locked startup defers notification navigation until unlock',
    () async {
      await tap();
      expect(getPath(), '/wallet');
      verifyNever(() => get.execute());
      await AppRouter.routeAfterUnlock();
      expect(getPath(), '/wallet/public-wallet');
    },
  );
  test(
    'relocking during destination resolution cannot bypass the gate',
    () async {
      await AppRouter.routeAfterUnlock();
      final pending = Completer<Result<List<Wallet>, WalletFailure>>();
      when(() => get.execute()).thenAnswer((_) => pending.future);
      gateway.response(NotificationsFacade.encodeDestination(destination));
      await pumpEventQueue();
      AppRouter.suspendNotificationRouting();
      pending.complete(Ok([wallet]));
      await pumpEventQueue(times: 30);
      expect(getPath(), '/wallet');
      expect(
        (await notifications.consumePendingDestination() as Ok).value,
        destination,
      );
    },
  );
  test(
    'a newer locked tap wins over an older interrupted resolution',
    () async {
      await AppRouter.routeAfterUnlock();
      final pending = Completer<Result<List<Wallet>, WalletFailure>>();
      when(() => get.execute()).thenAnswer((_) => pending.future);
      gateway.response(NotificationsFacade.encodeDestination(destination));
      await pumpEventQueue();
      AppRouter.suspendNotificationRouting();
      final second = publicBroadcastWallet(
        source: BitcoinSyncSource.compactBlockFilters,
      );
      final secondDestination = NotificationDestination.wallet(
        WalletPaymentNotificationIdentity.topicId(
          WalletNetworkKey(second.id, 'bitcoin', 'mainnet'),
        ),
      );
      gateway.response(
        NotificationsFacade.encodeDestination(secondDestination),
      );
      pending.complete(Ok([wallet, second]));
      await pumpEventQueue(times: 30);
      when(() => get.execute()).thenAnswer((_) async => Ok([wallet, second]));
      await AppRouter.routeAfterUnlock();
      expect(getPath(), '/wallet/private-wallet');
    },
  );
  test('the most recent of multiple deferred taps wins', () async {
    final second = publicBroadcastWallet(
      source: BitcoinSyncSource.compactBlockFilters,
    );
    when(() => get.execute()).thenAnswer((_) async => Ok([wallet, second]));
    expect(
      gateway.response(NotificationsFacade.encodeDestination(destination)),
      isA<Ok>(),
    );
    final secondDestination = NotificationDestination.wallet(
      WalletPaymentNotificationIdentity.topicId(
        WalletNetworkKey(second.id, 'bitcoin', 'mainnet'),
      ),
    );
    expect(
      gateway.response(
        NotificationsFacade.encodeDestination(secondDestination),
      ),
      isA<Ok>(),
    );
    await AppRouter.routeAfterUnlock();
    expect(getPath(), '/wallet/private-wallet');
    expect(
      (await notifications.consumePendingDestination() as Ok).value,
      isNull,
    );
  });
}
