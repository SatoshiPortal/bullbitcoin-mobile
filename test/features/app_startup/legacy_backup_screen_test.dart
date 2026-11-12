import 'package:bb_mobile/features/app_startup/ui/screens/legacy_backup_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('an unreadable store never offers deletion or a confirmation', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (_) async => true);
    await tester.pumpWidget(const LegacyBackupApp(secrets: null));
    await tester.pumpAndSettle();
    expect(find.textContaining('Do NOT delete the app'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Next steps'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('refused capture protection cannot mount the secret views', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    final storage = FakeSecureStoragePlatform()..install();
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    late Secret secret;
    await tester.runAsync(() async {
      final imported = await secrets.import(
        words: [...List.filled(11, 'abandon'), 'about'],
      );
      secret = (imported as Ok<Secret, SecretFailure>).value;
    });
    storage.reads = 0;
    await tester.pumpWidget(LegacyBackupApp(secrets: [secret]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Do NOT delete the app'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Next steps'), findsNothing);
    expect(find.byType(MnemonicView), findsNothing);
    expect(storage.reads, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
