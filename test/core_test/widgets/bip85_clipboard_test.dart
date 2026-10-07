import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bip85_derivation_widget.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String clipboard = '';

  setUp(() {
    clipboard = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              clipboard = (call.arguments as Map)['text'] as String;
              return null;
            case 'Clipboard.getData':
              return {'text': clipboard};
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget page({required bool showCard}) => MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: showCard
          ? Bip85DerivationWidget(
              entropy: 'dummy child entropy',
              derivation: Bip85DerivationEntity(
                path: "m/83696968'/39'/0'/12'/0'",
                xprvFingerprint: '00000000',
                alias: null,
                status: Bip85Status.active,
                application: Bip85Application.bip39,
                index: 0,
              ),
            )
          : const SizedBox.shrink(),
    ),
  );

  testWidgets('copied entropy expires after its card is disposed', (
    tester,
  ) async {
    await tester.pumpWidget(page(showCard: true));
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();
    expect(clipboard, 'dummy child entropy');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(page(showCard: false));
    await tester.pump(const Duration(seconds: 31));

    expect(clipboard, isEmpty);
  });

  testWidgets('cleanup preserves a later unrelated clipboard entry', (
    tester,
  ) async {
    await tester.pumpWidget(page(showCard: true));
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(page(showCard: false));
    clipboard = 'later unrelated text';
    await tester.pump(const Duration(seconds: 31));

    expect(clipboard, 'later unrelated text');
  });
}
