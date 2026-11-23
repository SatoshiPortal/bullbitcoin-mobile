import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/src/widgets/swap_mnemonic_view.dart';

void main() {
  testWidgets('keeps recovery text out of widgets and semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            child: SwapMnemonicView(
              readWords: () async => const Ok('private test value'),
              identity: 'first',
              style: const TextStyle(),
              failure: const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('private test value'), findsNothing);
    expect(find.byType(ExcludeSemantics), findsOneWidget);
  });
}
