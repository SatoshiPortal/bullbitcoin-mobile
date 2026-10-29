import 'dart:async';

import 'package:bb_mobile/cbf_foreground_service.dart';
import 'package:bb_mobile/cbf_foreground_sync.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

final class FakePermissionGateway implements NotificationPermissionGateway {
  bool enabled;
  final bool grantsRequest;
  int requests = 0;

  FakePermissionGateway({this.enabled = true, this.grantsRequest = false});

  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async => Ok(enabled);

  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async {
    requests++;
    enabled = grantsRequest;
    return Ok(enabled);
  }

  @override
  Future<Result<void, NotificationsFailure>> openSystemSettings() async =>
      const Ok(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/cbf_foreground');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late FakePermissionGateway permission;
  late AndroidCbfForegroundService service;

  const key = WalletNetworkKey('private-wallet', 'bitcoin', 'mainnet');

  BitcoinSyncProgress progress({
    WalletNetworkKey wallet = key,
    double? fraction,
    int? target = 973604,
    BitcoinSyncPhase phase = BitcoinSyncPhase.checkingBlocks,
    WalletTransactionSyncFailure? failure,
  }) => BitcoinSyncProgress(
    key: wallet,
    isRecovery: true,
    phase: phase,
    fraction: fraction,
    startHeight: 481823,
    reachedHeight: 688371,
    targetHeight: target,
    failure: failure,
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<CbfForegroundSync> notificationSync({
    String locale = 'en',
    required Duration Function() elapsed,
  }) async {
    final localized = await AppLocalizations.delegate.load(Locale(locale));
    return CbfForegroundSync(
      service: service,
      labels: () async => (
        title: localized.syncServiceTitle,
        body: localized.syncServiceBody,
        progressBody: localized.syncServiceProgressBody,
      ),
      onProtectionChanged: () {},
      elapsed: elapsed,
    );
  }

  Iterable<Map<dynamic, dynamic>> updates() => calls
      .where((call) => call.method == 'progress')
      .map((call) => call.arguments as Map);

  Future<void> lost(String owner) async {
    final response = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('lost', {'owner': owner, 'reason': 'timeout'}),
      ),
      (_) => response.complete(),
    );
    await response.future;
  }

  setUp(() {
    calls.clear();
    permission = FakePermissionGateway();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'start' || 'renew' => true,
        _ => null,
      };
    });
    service = AndroidCbfForegroundService(
      permissions: NotificationPermissionsFacade(gateway: permission),
      channel: channel,
      platform: TargetPlatform.android,
    );
  });

  tearDown(() async {
    await service.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  for (final locale in ['en', 'fr']) {
    test(
      'notification sends only localized percentage data in $locale',
      () async {
        final sync = await notificationSync(
          elapsed: () => Duration.zero,
          locale: locale,
        );
        addTearDown(sync.dispose);
        sync.observe(progress(fraction: 0.429));
        await settle();
        final arguments = calls.single.arguments as Map;
        expect(
          arguments.keys,
          unorderedEquals(['owner', 'title', 'body', 'percentage']),
        );
        expect(arguments['percentage'], 42);
        expect(
          arguments['body'],
          locale == 'en'
              ? 'Syncing wallet · 42%'
              : 'Synchronisation du portefeuille · 42 %',
        );
        expect(arguments['title'], 'Bull Bitcoin');
      },
    );
  }

  test(
    'coalesces integer percentage changes at five-second boundaries',
    () async {
      var elapsed = Duration.zero;
      final sync = await notificationSync(elapsed: () => elapsed);
      addTearDown(sync.dispose);
      sync.observe(progress(fraction: 0.42));
      await settle();
      elapsed = const Duration(milliseconds: 4999);
      sync.observe(progress(fraction: 0.43));
      sync.observe(progress(fraction: 0.449));
      sync.heartbeat();
      await settle();
      expect(updates(), isEmpty);
      elapsed = const Duration(seconds: 5);
      sync.heartbeat();
      await settle();
      expect(updates().map((update) => update['percentage']), [44]);
      elapsed = const Duration(seconds: 10);
      sync.observe(progress(fraction: 0.4499));
      sync.heartbeat();
      await settle();
      expect(updates(), hasLength(1));
      sync.observe(progress(fraction: 0.45));
      await settle();
      expect(updates().map((update) => update['percentage']), [44, 45]);
      elapsed = const Duration(milliseconds: 14999);
      sync.observe(progress(fraction: 0.46));
      await settle();
      expect(updates(), hasLength(2));
      elapsed = const Duration(seconds: 15);
      sync.heartbeat();
      await settle();
      expect(updates().map((update) => update['percentage']), [44, 45, 46]);
      final owner = (calls.first.arguments as Map)['owner'];
      for (final update in updates()) {
        expect(update.keys, unorderedEquals(['owner', 'body', 'percentage']));
        expect(update['owner'], owner);
      }
    },
  );

  test(
    'unknown tip stays indeterminate until a usable recovery fraction',
    () async {
      var elapsed = Duration.zero;
      final sync = await notificationSync(elapsed: () => elapsed);
      addTearDown(sync.dispose);
      sync.observe(
        progress(target: null, phase: BitcoinSyncPhase.findingPeers),
      );
      await settle();
      expect((calls.first.arguments as Map)['percentage'], isNull);
      expect((calls.first.arguments as Map)['body'], 'Syncing wallet');
      elapsed = const Duration(seconds: 5);
      sync.observe(progress(target: null, fraction: 0.2));
      await settle();
      expect(updates(), isEmpty);
      sync.observe(progress(fraction: 0.2));
      await settle();
      expect(updates().single['percentage'], 20);
      elapsed = const Duration(seconds: 10);
      sync.observe(progress(fraction: double.nan));
      await settle();
      expect(updates().last['percentage'], isNull);
      expect(updates().last['body'], 'Syncing wallet');
    },
  );

  test(
    'shared notification follows the least complete pending wallet',
    () async {
      var elapsed = Duration.zero;
      final sync = await notificationSync(elapsed: () => elapsed);
      addTearDown(sync.dispose);
      const other = WalletNetworkKey(
        'another-private-wallet',
        'bitcoin',
        'mainnet',
      );
      sync.observe(progress(fraction: 0.8));
      await settle();
      elapsed = const Duration(seconds: 5);
      sync.observe(progress(wallet: other, target: null));
      await settle();
      expect(updates().single['percentage'], isNull);
      elapsed = const Duration(seconds: 10);
      sync.observe(progress(wallet: other, fraction: 0.3));
      await settle();
      expect(updates().last['percentage'], 30);
      elapsed = const Duration(seconds: 15);
      sync.observe(progress(wallet: other, phase: BitcoinSyncPhase.done));
      await settle();
      expect(updates().last['percentage'], 80);
      expect(service.isActive, isTrue);
    },
  );

  test(
    'restart resets the notification throttle and uses a new owner',
    () async {
      var elapsed = Duration.zero;
      final sync = await notificationSync(elapsed: () => elapsed);
      addTearDown(sync.dispose);
      sync.observe(progress(fraction: 0.42));
      await settle();
      final firstOwner = (calls.first.arguments as Map)['owner'];
      sync.cancel(key);
      await settle();
      elapsed = const Duration(seconds: 1);
      sync.observe(progress(fraction: 0.12));
      await settle();
      final restart = calls.last.arguments as Map;
      expect(calls.last.method, 'start');
      expect(restart['percentage'], 12);
      expect(restart['owner'], isNot(firstOwner));
      elapsed = const Duration(seconds: 5);
      sync.observe(progress(fraction: 0.13));
      await settle();
      expect(updates(), isEmpty);
      elapsed = const Duration(seconds: 6);
      sync.heartbeat();
      await settle();
      expect(updates().single['percentage'], 13);
      expect(updates().single['owner'], restart['owner']);
    },
  );

  for (final fail in [false, true]) {
    test(
      'late progress ${fail ? 'error' : 'reply'} after disposal stays stopped',
      () async {
        var elapsed = Duration.zero;
        final sync = await notificationSync(elapsed: () => elapsed);
        sync.observe(progress(fraction: 0.42));
        await settle();
        final response = Completer<void>();
        Future<Object?> delayedProgress(MethodCall call) async {
          calls.add(call);
          if (call.method == 'progress') await response.future;
          return null;
        }

        messenger.setMockMethodCallHandler(channel, delayedProgress);
        elapsed = const Duration(seconds: 5);
        sync.observe(progress(fraction: 0.43));
        await settle();
        expect(updates(), hasLength(1));
        await sync.dispose();
        if (fail) {
          response.completeError(PlatformException(code: 'service_gone'));
        } else {
          response.complete();
        }
        await settle();
        elapsed = const Duration(seconds: 10);
        sync.heartbeat();
        await service.updateProgress(
          body: 'Syncing wallet · 44%',
          percentage: 44,
        );
        await settle();
        expect(service.isActive, isFalse);
        expect(calls.map((call) => call.method), ['start', 'progress', 'stop']);
      },
    );
  }

  for (final terminal in ['tip', 'failure', 'cancel', 'timeout']) {
    test('$terminal discards pending notification updates', () async {
      var elapsed = Duration.zero;
      final sync = await notificationSync(elapsed: () => elapsed);
      addTearDown(sync.dispose);
      sync.observe(progress(fraction: 0.42));
      await settle();
      sync.observe(progress(fraction: 0.43));
      await settle();
      switch (terminal) {
        case 'tip':
          sync.observe(progress(phase: BitcoinSyncPhase.done));
        case 'failure':
          sync.observe(progress(failure: const CbfTorUnavailableFailure()));
        case 'cancel':
          sync.cancel(key);
        case 'timeout':
          await lost((calls.first.arguments as Map)['owner'] as String);
      }
      await settle();
      elapsed = const Duration(seconds: 5);
      sync.heartbeat();
      await settle();
      expect(updates(), isEmpty);
      expect(service.isActive, isFalse);
    });
  }

  test(
    'start, renewal and stop use one opaque owner without a timer',
    () async {
      expect(
        await service.start(title: 'Bull Bitcoin', body: 'Syncing wallet'),
        isTrue,
      );
      expect(service.isActive, isTrue);
      expect(await service.renew(), isTrue);
      await service.stop();
      expect(service.isActive, isFalse);
      expect(calls.map((call) => call.method), ['start', 'renew', 'stop']);
      final owner = (calls.first.arguments as Map)['owner'];
      expect(owner, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect((calls[1].arguments as Map)['owner'], owner);
      expect((calls[2].arguments as Map)['owner'], owner);
    },
  );

  test(
    'denied notifications fall back without starting native protection',
    () async {
      permission.enabled = false;
      expect(
        await service.start(title: 'Bull Bitcoin', body: 'Syncing wallet'),
        isFalse,
      );
      expect(
        await service.start(title: 'Bull Bitcoin', body: 'Syncing wallet'),
        isFalse,
      );
      expect(permission.requests, 1);
      expect(calls, isEmpty);
      expect(service.isActive, isFalse);
    },
  );

  test(
    'native start rejection preserves the stop-on-background fallback',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async => false);
      expect(
        await service.start(title: 'Bull Bitcoin', body: 'Syncing wallet'),
        isFalse,
      );
      expect(service.isActive, isFalse);
    },
  );

  test('timeout clears protection once and ignores a foreign owner', () async {
    var losses = 0;
    final subscription = service.protectionLost.listen((_) => losses++);
    await service.start(title: 'Bull Bitcoin', body: 'Syncing wallet');
    final owner = (calls.first.arguments as Map)['owner'] as String;
    await lost('another-engine');
    expect(service.isActive, isTrue);
    await lost(owner);
    await lost(owner);
    expect(service.isActive, isFalse);
    expect(losses, 1);
    expect(await service.renew(), isFalse);
    await subscription.cancel();
  });

  test(
    'failed renewal informs lifecycle and stops claiming protection',
    () async {
      await service.start(title: 'Bull Bitcoin', body: 'Syncing wallet');
      final loss = service.protectionLost.first;
      messenger.setMockMethodCallHandler(channel, (call) async => false);
      expect(await service.renew(), isFalse);
      await loss;
      expect(service.isActive, isFalse);
    },
  );

  test(
    'stop during startup cancels a late successful native response',
    () async {
      final started = Completer<bool>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'start') return started.future;
        return null;
      });
      final starting = service.start(
        title: 'Bull Bitcoin',
        body: 'Syncing wallet',
      );
      // Cross the permission queries and deliver the native start method call.
      await Future<void>.delayed(Duration.zero);
      await service.stop();
      started.complete(true);
      expect(await starting, isFalse);
      expect(service.isActive, isFalse);
      expect(calls.last.method, 'stop');
    },
  );
}
