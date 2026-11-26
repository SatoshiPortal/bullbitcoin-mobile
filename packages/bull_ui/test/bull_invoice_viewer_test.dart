import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

const _invoice = 'lnbc1syntheticinvoicefixture';
const _clipboard = 'lightning:lnbc1syntheticinvoicefixture';
const _title = 'Lightning invoice';
const _copyLabel = 'Copy invoice';
const _copiedMessage = 'Invoice copied';

void main() {
  late String? copied;

  setUp(() {
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('long press copies the complete payment payload', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const BullInvoiceViewer(
          _invoice,
          clipboardText: _clipboard,
          title: _title,
          copyLabel: _copyLabel,
          copiedMessage: _copiedMessage,
        ),
      ),
    );

    final viewer = find.byType(BullInvoiceViewer);
    expect(tester.getSize(viewer).height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel(RegExp(_title)), findsWidgets);
    await tester.longPress(viewer);
    await tester.pumpAndSettle();

    expect(copied, _clipboard);
    expect(find.text(_copiedMessage), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('a surrounding control can show, copy, and dismiss the invoice', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => BullInvoiceViewer.showDetail(
              context,
              data: _invoice,
              clipboardText: _clipboard,
              title: _title,
              copyLabel: _copyLabel,
              copiedMessage: _copiedMessage,
            ),
            child: const Text('Show invoice'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show invoice'));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      _invoice,
    );
    await tester.tap(find.text(_copyLabel));
    await tester.pumpAndSettle();

    expect(copied, _clipboard);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.text(_copiedMessage), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
