import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/privacy_unavailable_notice.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:bb_mobile/features/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/reveal_backup_words_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_words_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_words_screen.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:screen_privacy/screen_privacy.dart';

class _Identity extends Mock implements NostrIdentityFacade {}

class _Unlock extends AppUnlockFacade {
  @override
  Widget buildReauthenticationGate({
    required ValueChanged<AppUnlockGrant> onSuccess,
    bool canPop = false,
  }) {
    final gate =
        super.buildReauthenticationGate(onSuccess: onSuccess, canPop: canPop)
            as PinCodeUnlockScreen;
    return Scaffold(
      body: TextButton(
        onPressed: gate.onSuccess,
        child: const Text('Authenticate fixture'),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
  final loc = AppLocalizationsEn();
  const words =
      'abandon differ wave love claim impact beach put bunker polar fragile crop';
  late _Identity identity;
  Completer<bool>? protection;

  Future<Result<String, NostrIdentityFailure>> reveal() =>
      identity.revealBackupWords(
        expectedOriginFingerprint: any(named: 'expectedOriginFingerprint'),
      );

  setUp(() {
    Device.screen = const Size(411, 890);
    identity = _Identity();
    protection = null;
    ScreenCaptureProtection.instance.enabledByUser = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'screenshotOff' && protection != null) {
            return protection!.future;
          }
          return true;
        });
  });

  tearDown(() {
    ScreenCaptureProtection.instance.enabledByUser = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// The Data Backup journey by default, and the vault journey when [forVault]
  /// is set, which is the only one that names an origin wallet.
  Future<void> open(
    WidgetTester tester, {
    String? originFingerprint,
    bool forVault = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => BackupWordsCubit(RevealBackupWordsUsecase(identity)),
        child: forVault
            ? BackupWordsScreen.forVault(
                appUnlock: _Unlock(),
                originFingerprint: originFingerprint,
              )
            : BackupWordsScreen(appUnlock: _Unlock()),
      ),
    ),
  );

  void expectNoWords() {
    for (final word in words.split(' ')) {
      expect(find.text(word), findsNothing);
    }
  }

  testWidgets('unlock, then capture protection, then the words', (
    tester,
  ) async {
    protection = Completer<bool>();
    when(reveal).thenAnswer((_) async => const Ok(words));

    await open(tester);
    await tester.pump();
    // Capture protection is the first gate: no PIN prompt and no derivation
    // until it confirms.
    expect(find.text('Authenticate fixture'), findsNothing);
    expectNoWords();
    verifyZeroInteractions(identity);

    protection!.complete(true);
    await tester.pumpAndSettle();
    // The PIN gate is next, and it is still the words that wait on it.
    expect(find.text('Authenticate fixture'), findsOneWidget);
    expectNoWords();
    verifyZeroInteractions(identity);

    await tester.tap(find.text('Authenticate fixture'));
    await tester.pumpAndSettle();
    expect(find.text('abandon'), findsOneWidget);
    expect(find.text('crop'), findsOneWidget);
    verify(reveal).called(1);
  });

  testWidgets('refused capture protection never derives the words', (
    tester,
  ) async {
    protection = Completer<bool>()..complete(false);
    when(reveal).thenAnswer((_) async => const Ok(words));

    await open(tester);
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyUnavailableNotice), findsOneWidget);
    expect(find.text('Authenticate fixture'), findsNothing);
    expectNoWords();
    verifyZeroInteractions(identity);
  });

  testWidgets('a device with no seed explains why and shows no words', (
    tester,
  ) async {
    when(
      reveal,
    ).thenAnswer((_) async => const Err(NostrIdentityUnavailableFailure()));

    await open(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Authenticate fixture'));
    await tester.pumpAndSettle();

    expect(find.text(loc.backupWordsUnavailable), findsOneWidget);
    expect(find.text(loc.backupWordsExplanation), findsOneWidget);
    expectNoWords();
  });

  testWidgets('backgrounding the app takes the words away again', (
    tester,
  ) async {
    when(reveal).thenAnswer((_) async => const Ok(words));

    await open(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Authenticate fixture'));
    await tester.pumpAndSettle();
    expect(find.text('abandon'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expectNoWords();
    expect(find.text('Authenticate fixture'), findsOneWidget);

    await tester.tap(find.text('Authenticate fixture'));
    await tester.pumpAndSettle();

    expect(find.text('abandon'), findsOneWidget);
    verify(reveal).called(2);
  });

  testWidgets('a vault from another wallet is told which words it needs', (
    tester,
  ) async {
    when(reveal).thenAnswer(
      (_) async => const Err(NostrIdentityForeignCredentialFailure()),
    );

    await open(tester, originFingerprint: 'deadbeef', forVault: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Authenticate fixture'));
    await tester.pumpAndSettle();

    expect(find.text(loc.backupWordsForeignWallet), findsOneWidget);
    expectNoWords();
    verify(
      () => identity.revealBackupWords(expectedOriginFingerprint: 'deadbeef'),
    ).called(1);
  });

  testWidgets('a vault that records no origin derives nothing', (tester) async {
    when(reveal).thenAnswer((_) async => const Ok(words));

    await open(tester, forVault: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Authenticate fixture'));
    await tester.pumpAndSettle();

    expect(find.text(loc.backupWordsForeignWallet), findsOneWidget);
    expectNoWords();
    verifyZeroInteractions(identity);
  });

  test('the cubit keeps a flag, never the words', () async {
    when(reveal).thenAnswer((_) async => const Ok(words));
    final cubit = BackupWordsCubit(RevealBackupWordsUsecase(identity));
    final states = <BackupWordsState>[];
    final subscription = cubit.stream.listen(states.add);

    expect(await cubit.reveal(), words.split(' '));
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    await cubit.close();

    expect(states.map((state) => state.loading), [true, false]);
    expect(states.every((state) => state.failure == null), isTrue);
    for (final state in states) {
      expect(state.toString(), isNot(contains('abandon')));
    }
  });
}
