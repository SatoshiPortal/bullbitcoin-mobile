import 'dart:async';

import 'package:bb_mobile/cbf_foreground_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

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
