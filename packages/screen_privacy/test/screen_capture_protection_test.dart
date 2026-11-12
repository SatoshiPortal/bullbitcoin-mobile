import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// The `no_screenshot` plugin flips the OS capture flag through this method
/// channel. We record the last method it received to assert what the
/// reference-counted controller decided.
const _channel = MethodChannel('com.flutterplaza.no_screenshot_methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final controller = ScreenCaptureProtection.instance;
  String? lastCall;
  // What the fake plugin answers to screenshotOff: true, false, or a throw.
  Object answer = true;

  setUp(() async {
    lastCall = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          lastCall = call.method;
          if (call.method != 'screenshotOff') return true;
          if (answer case final Exception e) throw e;
          return answer;
        });

    // The controller is a process-wide singleton, so normalise it to a known
    // baseline before each test: preference on, no screens acquired. release()
    // is clamped at zero, so over-releasing is a safe way to drain the count.
    for (var i = 0; i < 100; i++) {
      await controller.release();
    }
    controller.enabledByUser = true;
    answer = true;
    lastCall = null;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('protects while at least one screen is mounted', () async {
    await controller.acquire();
    expect(lastCall, 'screenshotOff');
  });

  test('only clears protection once the last screen is gone', () async {
    await controller.acquire();
    await controller.acquire();

    lastCall = null;
    await controller.release();
    // Still one screen mounted: must stay protected.
    expect(lastCall, 'screenshotOff');

    await controller.release();
    // Last screen gone: protection lifted.
    expect(lastCall, 'screenshotOn');
  });

  test('does not protect when the user has opted out', () async {
    controller.enabledByUser = false;
    await pumpEventQueue();
    lastCall = null;

    await controller.acquire();
    expect(lastCall, 'screenshotOn');
  });

  test('opting out while a protected screen is mounted lifts protection '
      'immediately', () async {
    await controller.acquire();
    expect(lastCall, 'screenshotOff');

    controller.enabledByUser = false;
    await pumpEventQueue();
    expect(lastCall, 'screenshotOn');
  });

  test('opting back in re-applies protection to a mounted screen', () async {
    await controller.acquire();
    controller.enabledByUser = false;
    await pumpEventQueue();
    expect(lastCall, 'screenshotOn');

    controller.enabledByUser = true;
    await pumpEventQueue();
    expect(lastCall, 'screenshotOff');
  });

  group('the verdict a secret screen waits for', () {
    test('is true once capture blocking is in effect', () async {
      expect(await controller.acquire(), isTrue);
    });

    test('is false when the platform refuses', () async {
      answer = false;

      expect(await controller.acquire(), isFalse);
    });

    test('is false when the platform throws', () async {
      answer = PlatformException(code: 'no-window');

      expect(await controller.acquire(), isFalse);
    });

    test('is true when the user turned protection off', () async {
      controller.enabledByUser = false;
      await pumpEventQueue();
      answer = false;

      expect(await controller.acquire(), isTrue);
    });

    test('a retry after a refusal can succeed', () async {
      answer = false;
      expect(await controller.acquire(), isFalse);

      answer = true;
      expect(await controller.resync(), isTrue);
    });
  });
}
