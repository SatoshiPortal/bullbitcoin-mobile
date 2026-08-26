import 'package:bull_recoverbull/src/domain/entity/vault_provider.dart';
import 'package:bull_recoverbull/src/ui/support.dart';
import 'package:bull_recoverbull/src/widgets/provider_cart.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_recoverbull/src/ui/pages/vault_created_page.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:gif/gif.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CopyInput copies clipboardText, not masked display text', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [RecoverBullLocalizations.delegate],
        home: Scaffold(
          body: CopyInput(text: '******', clipboardText: 'secret-value'),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.copy_sharp));
    await tester.pump();
    expect(copied, 'secret-value');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets('CopyInput only shows reveal when enabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [RecoverBullLocalizations.delegate],
        home: Scaffold(body: CopyInput(text: 'value')),
      ),
    );
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [RecoverBullLocalizations.delegate],
        home: Scaffold(body: CopyInput(text: 'value', canShowValueModal: true)),
      ),
    );
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('CopyInput uses localized modal actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [RecoverBullLocalizations.delegate],
        home: Scaffold(body: CopyInput(text: 'value', canShowValueModal: true)),
      ),
    );
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('CopyInput keeps the modal activatable while loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [RecoverBullLocalizations.delegate],
        home: Scaffold(body: CopyInput(canShowValueModal: true)),
      ),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('DialPad forwards each digit and backspace once', (tester) async {
    final digits = <String>[];
    var backspaces = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [RecoverBullLocalizations.delegate],
        home: Scaffold(
          body: DialPad(
            onlyDigits: true,
            onNumberPressed: digits.add,
            onBackspacePressed: () => backspaces++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('7'));
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    expect(digits, ['7']);
    expect(backspaces, 1);
    expect(find.text('.'), findsNothing);
  });

  testWidgets('provider selector hides iCloud and preserves callbacks', (
    tester,
  ) async {
    final selected = <VaultProvider>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [RecoverBullLocalizations.delegate],
        home: Scaffold(
          body: RecoverbullVaultProviderSelector(
            onProviderSelected: selected.add,
          ),
        ),
      ),
    );

    expect(find.text('iCloud'), findsNothing);
    await tester.tap(find.text('Google Drive'));
    expect(selected, [VaultProvider.googleDrive]);
    await tester.tap(find.text('Custom location'));
    expect(selected, [VaultProvider.googleDrive, VaultProvider.customLocation]);
  });

  testWidgets('ProgressScreen uses the Bull UI loading GIF at 200 pixels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProgressScreen(isLoading: true)),
    );
    final gif = tester.widget<Gif>(find.byType(Gif));
    expect(gif.width, 200);
    expect(gif.height, 200);
    expect((gif.image as AssetImage).package, 'bull_ui');
  });

  testWidgets(
    'BackupSuccessScreen has animated asset and invokes bottom action',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: BackupSuccessScreen(
            title: 'Done',
            message: 'Message',
            buttonLabel: 'Got it',
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.byType(BullTopBar), findsNothing);
      expect(find.byType(Gif), findsOneWidget);
      await tester.tap(find.text('Got it'));
      expect(tapped, isTrue);
    },
  );

  testWidgets('VaultCreatedPage uses the animated backup success screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: VaultCreatedPage(),
      ),
    );

    expect(find.byType(StatusScreen), findsNothing);
    final gif = tester.widget<Gif>(find.byType(Gif));
    expect(gif.width, 200);
    expect(gif.height, 200);
    expect((gif.image as AssetImage).package, 'bull_ui');
    expect(find.text('Test Recovery'), findsOneWidget);
  });

  testWidgets('StatusScreen keeps its action outside the scroll view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [RecoverBullLocalizations.delegate],
        home: const StatusScreen(isLoading: false, onTap: _noop),
      ),
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
  });

  testWidgets('provider card renders its package icon and localized label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [RecoverBullLocalizations.delegate],
        home: Scaffold(
          body: ProviderCard(provider: VaultProvider.googleDrive, onTap: _noop),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image).first);
    expect((image.image as AssetImage).package, 'bull_recoverbull');
    expect(find.text('Google Drive'), findsOneWidget);
  });
}

void _noop() {}
