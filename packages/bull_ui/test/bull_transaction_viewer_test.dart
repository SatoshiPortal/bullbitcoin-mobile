import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

void main() {
  testWidgets('resolves only the explicitly selected explorer action', (
    tester,
  ) async {
    final copied = <String>[];
    final opened = <Uri>[];
    final resolutions = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    const publicUrl = 'https://explorer.example/tx/public';
    const disclosureUrl = '$publicUrl?showDetails=true#fixture';
    await tester.pumpWidget(
      wrapWithTheme(
        Scaffold(
          body: BullTransactionViewer(
            'public',
            title: 'Transaction ID',
            copyLabel: 'Copy ID',
            copiedMessage: 'Copied',
            openUrl: (url) async => opened.add(url),
            explorerActions: [
              (
                copyLabel: 'Copy link',
                openLabel: 'Open explorer',
                resolveUrl: () async {
                  resolutions.add('public');
                  return publicUrl;
                },
              ),
              (
                copyLabel: 'Copy disclosure link',
                openLabel: 'Open disclosure link',
                resolveUrl: () async {
                  resolutions.add('disclosure');
                  return disclosureUrl;
                },
              ),
            ],
          ),
        ),
      ),
    );

    final trigger = find.byType(BullTransactionViewer);
    expect(tester.getSize(trigger).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(trigger).height, greaterThanOrEqualTo(48));
    await tester.longPress(trigger);
    await tester.pump(const Duration(seconds: 4));
    expect(copied, ['public']);
    expect(resolutions, isEmpty);

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(resolutions, isEmpty);
    for (final action in tester.widgetList(
      find.byType(BullViewerActionButton),
    )) {
      expect(
        tester.getSize(find.byWidget(action)).height,
        greaterThanOrEqualTo(48),
      );
    }
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, ['public', publicUrl]);
    expect(resolutions, ['public']);
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open disclosure link'));
    await tester.pumpAndSettle();
    expect(resolutions, ['public', 'disclosure']);
    expect(opened, [Uri.parse(disclosureUrl)]);
  });
}
