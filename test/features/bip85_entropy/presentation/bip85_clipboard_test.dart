import 'package:bb_mobile/features/bip85_entropy/presentation/bip85_clipboard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'copy lifetime is independent of the screen and preserves later copies',
    (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        },
      );
      await Bip85Clipboard.copy('test-only-entropy');
      await tester.pump(const Duration(seconds: 30));
      expect(clipboard, '');
      await Bip85Clipboard.copy('test-only-next');
      clipboard = 'unrelated copy';
      await tester.pump(const Duration(seconds: 30));
      expect(clipboard, 'unrelated copy');
      await Bip85Clipboard.copy('first');
      await tester.pump(const Duration(seconds: 20));
      await Bip85Clipboard.copy('second');
      await tester.pump(const Duration(seconds: 10));
      expect(clipboard, 'second');
      await tester.pump(const Duration(seconds: 20));
      expect(clipboard, '');
    },
  );
}
