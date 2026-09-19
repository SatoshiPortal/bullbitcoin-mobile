import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/reveal_data_recovery_words_usecase.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/data_recovery_words_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Reveal extends Mock implements RevealDataRecoveryWordsUsecase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const privacyChannel = MethodChannel(
    'com.flutterplaza.no_screenshot_methods',
  );
  const words =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  const explanation =
      "These 12 words allow anyone to discover and decrypt your Data Backup. They DO NOT allow you to recover your wallet funds. They are NOT your wallet seed. They are automatically generated from your wallet seed, they don't need to be backed up separately unless you want to give access to data backups to someone else, for example in an inheritance situation.";
  late _Reveal reveal;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacyChannel, (_) async => true);
    reveal = _Reveal();
    locator.registerSingleton<RevealDataRecoveryWordsUsecase>(reveal);
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
    'sealed display reads once and keeps the exact data-only explanation',
    (tester) async {
      when(
        () => reveal.execute(expectedFingerprint: 'aabbccdd', forVault: true),
      ).thenAnswer((_) async => const Ok(RevealedDataRecoveryWords(words)));
      await pump(tester, origin: 'aabbccdd');
      await tester.pumpAndSettle();
      expect(find.text(explanation), findsOneWidget);
      expect(find.text('12. about'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('12. about'),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
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
      final pending =
          Completer<Result<RevealedDataRecoveryWords, BackupSettingsFailure>>();
      when(
        () => reveal.execute(expectedFingerprint: 'aabbccdd', forVault: true),
      ).thenAnswer((_) async => const Ok(RevealedDataRecoveryWords(words)));
      when(
        () => reveal.execute(expectedFingerprint: '11223344', forVault: true),
      ).thenAnswer((_) => pending.future);
      await pump(tester, origin: 'aabbccdd');
      await tester.pumpAndSettle();
      expect(find.text('12. about'), findsOneWidget);
      await pump(tester, origin: '11223344');
      await tester.pump();
      expect(find.text('12. about'), findsNothing);
      pending.complete(const Err(BackupSettingsWordsUnavailableFailure()));
      await tester.pumpAndSettle();
      expect(find.text('12. about'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
