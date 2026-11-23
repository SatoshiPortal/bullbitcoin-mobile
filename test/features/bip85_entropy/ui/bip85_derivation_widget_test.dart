import 'package:bip85/bip85.dart';
// Regression coverage for security audit #2644: copied derivations must
// expire even after their screen closes. Entropy derivation/controller
// lifetime is outside this clipboard mitigation.

import 'package:secrets/bip85.dart';
import 'package:bip85/testing.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _Derivation extends Fake implements Bip85Derivation {
  @override
  final String path;
  @override
  final String? alias;
  @override
  final Bip85Status status;
  @override
  final Bip85Application application;

  _Derivation({
    required this.path,
    required this.alias,
    required this.status,
    required this.application,
  });
}

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
        localizationsDelegates: [
          Bip85Localizations.delegate,
          ...appLocalizationsDelegates,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Bip85DerivationWidget(
            derivation: _Derivation(
              path: 'test-path',
              alias: 'test',
              status: Bip85Status.active,
              application: Bip85Application.hex,
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
