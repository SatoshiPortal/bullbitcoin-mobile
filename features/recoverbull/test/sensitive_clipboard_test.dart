import 'dart:async';

import 'package:bull_recoverbull/src/presentation/sensitive_clipboard.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? clipboard;
  setUp(() => clipboard = null);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
          return null;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      },
    );
  }

  testWidgets('expires its value after thirty seconds', (tester) async {
    install(tester);
    final controller = SensitiveClipboard();
    await controller.copy('synthetic backup key');
    await tester.pump(const Duration(seconds: 29));
    expect(clipboard, 'synthetic backup key');
    await tester.pump(const Duration(seconds: 1));
    expect(clipboard, '');
    controller.dispose();
  });

  testWidgets('keeps foreign clipboard content on close', (tester) async {
    install(tester);
    final controller = SensitiveClipboard();
    await controller.copy('synthetic backup key');
    clipboard = 'later foreign content';
    controller.dispose();
    await tester.pump();
    expect(clipboard, 'later foreign content');
  });

  testWidgets('a late copy is cleared after disposal', (tester) async {
    final copied = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final value = (call.arguments as Map)['text'] as String;
          if (value.isNotEmpty) await copied.future;
          clipboard = value;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      },
    );
    final controller = SensitiveClipboard();
    final result = controller.copy('synthetic backup key');
    controller.dispose();
    copied.complete();
    expect(await result, isFalse);
    expect(clipboard, '');
  });

  testWidgets('deferred cleanup retries when clipboard becomes readable', (
    tester,
  ) async {
    var readable = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') {
          if (!readable) throw PlatformException(code: 'background');
          return {'text': clipboard};
        }
        return null;
      },
    );
    final controller = SensitiveClipboard();
    await controller.copy('synthetic backup key');
    controller.dispose();
    await tester.pump();
    expect(clipboard, 'synthetic backup key');
    readable = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(clipboard, '');
  });
}
