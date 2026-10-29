import 'dart:async';
import 'package:bb_mobile/cbf_background_persistence.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/cbf_background');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('iOS assertion brackets persistence and ends only once', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'begin' ? true : null;
    });
    final persistence = CbfBackgroundPersistence(
      channel: channel,
      platform: TargetPlatform.iOS,
    );
    expect(await persistence.begin(), isTrue);
    await persistence.end();
    await persistence.end();
    await persistence.dispose();
    expect(calls, ['begin', 'end']);
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('denial does not require ending an ungranted assertion', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return false;
    });
    final persistence = CbfBackgroundPersistence(
      channel: channel,
      platform: TargetPlatform.iOS,
    );
    expect(await persistence.begin(), isFalse);
    await persistence.dispose();
    expect(calls, ['begin']);
    messenger.setMockMethodCallHandler(channel, null);
  });
  test(
    'resume ends an assertion even when its begin reply is still pending',
    () async {
      final entered = Completer<void>();
      final granted = Completer<bool>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'begin') {
          entered.complete();
          return granted.future;
        }
        return null;
      });
      final persistence = CbfBackgroundPersistence(
        channel: channel,
        platform: TargetPlatform.iOS,
      );
      final begin = persistence.begin();
      await entered.future;
      final end = persistence.end();
      granted.complete(true);
      expect(await begin, isTrue);
      await end;
      await persistence.dispose();
      expect(calls, ['begin', 'end']);
      expect(await persistence.begin(), isFalse);
      messenger.setMockMethodCallHandler(channel, null);
    },
  );
}
