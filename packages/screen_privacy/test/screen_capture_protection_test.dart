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

  setUp(() async {
    lastCall = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          lastCall = call.method;
          return true;
        });

    // The controller is a process-wide singleton, so normalise it to a known
    // baseline before each test: preference on, no screens acquired. release()
    // is clamped at zero, so over-releasing is a safe way to drain the count.
    for (var i = 0; i < 100; i++) {
      await controller.release();
    }
    controller.enabledByUser = true;
    lastCall = null;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('refuses to report protection the OS did not confirm', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          throw PlatformException(code: 'unavailable');
        });

    await expectLater(
      controller.acquire(),
      throwsA(isA<ScreenCaptureProtectionException>()),
    );
    // The screen still holds its reference and releases normally.
    await controller.release();
  });

  test('protects while at least one screen is mounted', () async {
    await controller.acquire();
    expect(lastCall, 'screenshotOff');
  });

  for (final response in [false, null]) {
    test(
      'refuses a $response platform response and balances failed mounts',
      () async {
        var accepted = false;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_channel, (call) async {
              lastCall = call.method;
              return accepted ? true : response;
            });

        await expectLater(
          controller.acquire(),
          throwsA(isA<ScreenCaptureProtectionException>()),
        );
        accepted = true;
        await controller.acquire();
        // Unmounting the failed screen must not unprotect the successful one.
        await controller.release();
        expect(lastCall, 'screenshotOff');
        await controller.release();
        expect(lastCall, 'screenshotOn');
      },
    );
  }

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
}
