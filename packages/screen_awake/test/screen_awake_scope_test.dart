import 'package:bull_logger/bull_logger.dart';
import 'package:screen_awake/screen_awake.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _MockLogger extends Mock implements Logger {}

class _Wakelock extends WakelockPlusPlatformInterface {
  bool awake = false;
  bool unavailable = false;

  @override
  Future<void> toggle({required bool enable}) async {
    if (unavailable) throw PlatformException(code: 'unavailable');
    awake = enable;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _Wakelock wakelock;
  late WakelockPlusPlatformInterface previousPlatform;

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    previousPlatform = wakelockPlusPlatformInstance;
    wakelock = _Wakelock();
    wakelockPlusPlatformInstance = wakelock;
  });

  tearDown(() {
    wakelockPlusPlatformInstance = previousPlatform;
  });

  testWidgets('keeps awake only while enabled and mounted', (tester) async {
    Widget screen(bool enabled) =>
        ScreenAwakeScope(enabled: enabled, child: const SizedBox());

    await tester.pumpWidget(screen(false));
    expect(wakelock.awake, isFalse);
    await tester.pumpWidget(screen(true));
    expect(wakelock.awake, isTrue);
    await tester.pumpWidget(screen(false));
    expect(wakelock.awake, isFalse);
    await tester.pumpWidget(screen(true));
    await tester.pumpWidget(const SizedBox());
    expect(wakelock.awake, isFalse);
  });

  testWidgets('allows sleep in the background and reacquires on resume', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ScreenAwakeScope(enabled: true, child: SizedBox()),
    );
    expect(wakelock.awake, isTrue);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(wakelock.awake, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(wakelock.awake, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(wakelock.awake, isFalse);
  });

  testWidgets('a platform failure does not interrupt the screen', (
    tester,
  ) async {
    final previousLogger = log;
    log = _MockLogger();
    addTearDown(() => log = previousLogger);
    wakelock.unavailable = true;

    await tester.pumpWidget(
      const ScreenAwakeScope(enabled: true, child: SizedBox()),
    );
    expect(tester.takeException(), isNull);

    wakelock.unavailable = false;
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('keeps awake until the last enabled screen is removed', (
    tester,
  ) async {
    const first = ScreenAwakeScope(
      key: ValueKey('first'),
      enabled: true,
      child: SizedBox(),
    );
    const second = ScreenAwakeScope(
      key: ValueKey('second'),
      enabled: true,
      child: SizedBox(),
    );
    await tester.pumpWidget(const Column(children: [first, second]));
    expect(wakelock.awake, isTrue);
    await tester.pumpWidget(const Column(children: [second]));
    expect(wakelock.awake, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(wakelock.awake, isFalse);
  });
}
