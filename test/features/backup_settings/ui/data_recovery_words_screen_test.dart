import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_data_recovery_secret_usecase.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/data_recovery_words_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import '../../nostr_identity/fixtures/backup_secret_fixture.dart';

class _Reveal extends Mock implements GetDataRecoverySecretUsecase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const privacyChannel = MethodChannel(
    'com.flutterplaza.no_screenshot_methods',
  );
  const words =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  late _Reveal reveal;
  late Secret secret;
  setUp(() async {
    secret = await backupSecretFixture();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacyChannel, (_) async => true);
    reveal = _Reveal();
    locator.registerSingleton<GetDataRecoverySecretUsecase>(reveal);
  });
  tearDown(() async {
    await locator.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacyChannel, null);
  });

  Future<void> pump(WidgetTester tester, {String? origin}) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DataRecoveryWordsScreen.forVault(expectedFingerprint: origin),
    ),
  );

  testWidgets(
    'sealed display reads once and shows the localized data-only explanation',
    (tester) async {
      when(
        () => reveal.execute(expectedFingerprint: 'aabbccdd', forVault: true),
      ).thenAnswer((_) async => Ok(secret));
      await pump(tester, origin: 'aabbccdd');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizationsEn().dataBackupWordsExplanation),
        findsOneWidget,
      );
      expect(find.byType(MnemonicView), findsOneWidget);
      expect(find.textContaining(words), findsNothing);
      await pump(tester, origin: 'aabbccdd');
      verify(
        () => reveal.execute(expectedFingerprint: 'aabbccdd', forVault: true),
      ).called(1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'changing the vault origin clears old words while the new read waits',
    (tester) async {
      final pending = Completer<Result<Secret, BackupSettingsFailure>>();
      when(
        () => reveal.execute(expectedFingerprint: 'aabbccdd', forVault: true),
      ).thenAnswer((_) async => Ok(secret));
      when(
        () => reveal.execute(expectedFingerprint: '11223344', forVault: true),
      ).thenAnswer((_) => pending.future);
      await pump(tester, origin: 'aabbccdd');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MnemonicView), findsOneWidget);
      await pump(tester, origin: '11223344');
      await tester.pump();
      expect(find.byType(MnemonicView), findsNothing);
      pending.complete(const Err(BackupSettingsWordsUnavailableFailure()));
      await tester.pumpAndSettle();
      expect(find.byType(MnemonicView), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('privacy refusal never reads the secret or mounts its view', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacyChannel, (_) async => false);
    await pump(tester, origin: 'aabbccdd');
    await tester.pumpAndSettle();
    verifyZeroInteractions(reveal);
    expect(find.byType(MnemonicView), findsNothing);
    expect(
      find.text(AppLocalizationsEn().dataBackupWordsUnavailable),
      findsOneWidget,
    );
  });
}
