import 'package:secrets/secrets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final calls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return false;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    calls.clear();
  });

  test('prewarm initializes the secure storage on Android', () async {
    await Secrets.prewarmStorage();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'containsKey');
    expect(calls.single.arguments, {
      'key': '__bull_secure_storage_prewarm__',
      'options': containsPair('migrateOnAlgorithmChange', 'false'),
    });
  });

  test('prewarm does nothing off Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await Secrets.prewarmStorage();

    expect(calls, isEmpty);
  });

  test('prewarm leaves initialization failures to the first read', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          throw PlatformException(code: 'storage_error');
        });

    await expectLater(Secrets.prewarmStorage(), completes);

    expect(calls, hasLength(1));
  });
}
