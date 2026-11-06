import 'package:bull_logger/bull_logger.dart';
import 'package:screen_awake/screen_awake.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bull/screen_awake');
  var awake = false;

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    awake = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'setEnabled');
      awake = call.arguments as bool;
      return null;
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('keeps awake only while enabled and mounted', (tester) async {
    Widget screen(bool enabled) =>
        ScreenAwakeScope(enabled: enabled, child: const SizedBox());

    await tester.pumpWidget(screen(false));
    expect(awake, isFalse);
    await tester.pumpWidget(screen(true));
    expect(awake, isTrue);
    await tester.pumpWidget(screen(false));
    expect(awake, isFalse);
    await tester.pumpWidget(screen(true));
    await tester.pumpWidget(const SizedBox());
    expect(awake, isFalse);
  });

  testWidgets('allows sleep in the background and reacquires on resume', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ScreenAwakeScope(enabled: true, child: SizedBox()),
    );
    expect(awake, isTrue);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(awake, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(awake, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(awake, isFalse);
  });

  testWidgets('logs a platform failure without interrupting the screen', (
    tester,
  ) async {
    final previousLogger = log;
    final logger = _MockLogger();
    log = logger;
    addTearDown(() => log = previousLogger);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });

    await tester.pumpWidget(
      const ScreenAwakeScope(enabled: true, child: SizedBox()),
    );
    expect(tester.takeException(), isNull);
    verify(
      () => logger.warning(
        'Screen awake update failed',
        error: PlatformException,
        trace: any(named: 'trace'),
      ),
    ).called(1);
    verifyNoMoreInteractions(logger);

    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => null,
    );
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
    expect(awake, isTrue);
    await tester.pumpWidget(const Column(children: [second]));
    expect(awake, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(awake, isFalse);
  });
}
