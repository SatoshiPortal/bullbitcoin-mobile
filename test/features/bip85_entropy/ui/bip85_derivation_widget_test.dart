// Regression coverage for security audit #2644: copied derivations must
// expire even after their screen closes. Entropy derivation/controller
// lifetime is outside this clipboard mitigation.

import 'package:bb_mobile/features/bip85_entropy/domain/bip85_derivation_entity.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/bip85_entropy/ui/bip85_derivation_widget.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('leaving the derivation screen still clears its copied value', (
    tester,
  ) async {
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
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Bip85DerivationWidget(
            derivation: Bip85DerivationEntity(
              path: 'test-path',
              xprvFingerprint: 'public-test-id',
              alias: 'test',
              status: Bip85Status.active,
              application: Bip85Application.hex,
              index: 0,
            ),
            entropy: 'test-only-value',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();
    expect(clipboard, 'test-only-value');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
    expect(clipboard, '');
  });
}
