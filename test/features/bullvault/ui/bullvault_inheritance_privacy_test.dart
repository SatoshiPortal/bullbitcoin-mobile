import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/core/widgets/privacy_unavailable_notice.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_inheritance_mnemonic_flow.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => Device.screen = const Size(800, 600));
  const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');

  for (final generated in [false, true]) {
    testWidgets(
      '${generated ? 'generated' : 'imported'} inheritance flow hides secrets until protection succeeds',
      (tester) async {
        final protection = Completer<bool>();
        final calls = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            calls.add(call.method);
            return call.method == 'screenshotOff' ? protection.future : true;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        });
        await _open(tester, generated: generated);
        expect(calls, contains('screenshotOff'));
        expect(find.byType(MnemonicWidget), findsNothing);
        expect(find.byType(ShowMnemonicScreen), findsNothing);
        expect(find.byType(PrivacyUnavailableNotice), findsNothing);

        protection.complete(false);
        await tester.pumpAndSettle();
        expect(find.byType(PrivacyUnavailableNotice), findsOneWidget);
        expect(find.byType(MnemonicWidget), findsNothing);
        expect(find.byType(ShowMnemonicScreen), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(calls.last, 'screenshotOn');
      },
    );
  }

  testWidgets('inheritance import becomes editable after protection succeeds', (
    tester,
  ) async {
    final protection = Completer<bool>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'screenshotOff' ? protection.future : true,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    await _open(tester, generated: false);
    expect(find.byType(MnemonicWidget), findsNothing);
    protection.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(MnemonicWidget), findsOneWidget);
    expect(find.byType(PrivacyUnavailableNotice), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('leaving during protection does not reopen inheritance entry', (
    tester,
  ) async {
    final protection = Completer<bool>();
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return call.method == 'screenshotOff' ? protection.future : true;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    await _open(tester, generated: false);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    protection.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(MnemonicWidget), findsNothing);
    expect(calls.last, 'screenshotOn');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _open(WidgetTester tester, {required bool generated}) async {
  final previousScreen = Device.screen;
  Device.screen = const Size(800, 600);
  addTearDown(() => Device.screen = previousScreen);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showBullVaultInheritanceMnemonic(
              context,
              network: Network.bitcoinTestnet,
              generated: generated,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
