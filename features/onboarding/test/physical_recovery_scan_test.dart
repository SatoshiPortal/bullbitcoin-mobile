import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:mnemonic_entry/mnemonic_entry.dart';
import 'package:onboarding/onboarding.dart';
import 'package:onboarding/src/domain/usecases/scan_onboarding_wallet_usecase.dart';
import 'package:onboarding/src/presentation/bloc/onboarding_bloc.dart';
import 'package:onboarding/src/ui/screens/onboarding_physical_recovery.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/bull_ui.dart' show BullFadingLinearProgress;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

abstract interface class _Recovery {
  Future<Result<void, OnboardingFailure>> execute({
    required List<String> mnemonicWords,
    required bip39.Language language,
    required String passphrase,
  });
}

class _Recover extends Mock implements _Recovery {}

class _Scan extends Mock implements ScanOnboardingWalletUsecase {}

const _delegates = [
  OnboardingLocalizations.delegate,
  MnemonicEntryLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

void main() {
  setUpAll(() => registerFallbackValue(bip39.Language.english));
  testWidgets('the keyboard offers every recovery phrase language', (
    tester,
  ) async {
    const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => true);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final bloc = OnboardingBloc(
      createWallet: () async => const Ok(null),
      recoverWallet: _Recover().execute,
      scanOnboardingWalletUsecase: _Scan(),
    );
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: _delegates,
        supportedLocales: OnboardingLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: const OnboardingPhysicalRecovery(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mnemonicLanguageKey')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an empty scan asks before recovering the wallet', (
    tester,
  ) async {
    const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => true);
    final recover = _Recover();
    final recovery = Completer<Result<void, OnboardingFailure>>();
    final scan = _Scan();
    when(
      () => scan.execute(
        language: any(named: 'language'),
        words: any(named: 'words'),
        passphrase: any(named: 'passphrase'),
      ),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => recover.execute(
        language: any(named: 'language'),
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      ),
    ).thenAnswer((_) => recovery.future);
    final bloc = OnboardingBloc(
      createWallet: () async => const Ok(null),
      recoverWallet: recover.execute,
      scanOnboardingWalletUsecase: scan,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: _delegates,
        supportedLocales: OnboardingLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: const OnboardingPhysicalRecovery(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).onSubmit((
      words: const ['abandon'],
      passphrase: 'pass',
      label: '',
      language: bip39.Language.english,
    ));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'This wallet looks empty. The passphrase may be wrong.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'No Bitcoin transaction history was found. Liquid has not been checked.',
      ),
      findsOneWidget,
    );
    verifyNever(
      () => recover.execute(
        language: any(named: 'language'),
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      ),
    );
    await tester.tap(find.text('Correct'));
    await tester.pumpAndSettle();
    verifyNever(
      () => recover.execute(
        language: any(named: 'language'),
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      ),
    );
    tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).onSubmit((
      words: const ['abandon'],
      passphrase: 'pass',
      label: '',
      language: bip39.Language.english,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    verify(
      () => recover.execute(
        mnemonicWords: ['abandon'],
        language: bip39.Language.english,
        passphrase: 'pass',
      ),
    ).called(1);
    recovery.complete(const Err(OnboardingWalletSetupFailure()));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    unawaited(bloc.close());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets(
    'a scan completed after the app becomes inactive cannot recover',
    (tester) async {
      const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => true);
      final recover = _Recover();
      final scan = _Scan();
      final pending = Completer<Result<bool, OnboardingFailure>>();
      when(
        () => scan.execute(
          language: any(named: 'language'),
          words: any(named: 'words'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) => pending.future);
      final bloc = OnboardingBloc(
        createWallet: () async => const Ok(null),
        recoverWallet: recover.execute,
        scanOnboardingWalletUsecase: scan,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: _delegates,
          supportedLocales: OnboardingLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: bloc,
            child: const OnboardingPhysicalRecovery(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).onSubmit((
        words: const ['abandon'],
        passphrase: 'pass',
        label: '',
        language: bip39.Language.english,
      ));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      pending.complete(const Ok(false));
      await tester.pumpAndSettle();
      expect(find.textContaining('This wallet looks empty'), findsNothing);
      verifyNever(
        () => recover.execute(
          language: any(named: 'language'),
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      unawaited(bloc.close());
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
  testWidgets('a failed scan offers retry or continuing without verification', (
    tester,
  ) async {
    const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => true);
    final recover = _Recover();
    final scan = _Scan();
    final recovery = Completer<Result<void, OnboardingFailure>>();
    when(
      () => recover.execute(
        language: any(named: 'language'),
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      ),
    ).thenAnswer((_) => recovery.future);
    when(
      () => scan.execute(
        language: any(named: 'language'),
        words: any(named: 'words'),
        passphrase: any(named: 'passphrase'),
      ),
    ).thenAnswer((_) async => const Err(OnboardingWalletScanFailure()));
    final bloc = OnboardingBloc(
      createWallet: () async => const Ok(null),
      recoverWallet: recover.execute,
      scanOnboardingWalletUsecase: scan,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: _delegates,
        supportedLocales: OnboardingLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: const OnboardingPhysicalRecovery(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).onSubmit((
      words: const ['abandon'],
      passphrase: ' pass ',
      label: '',
      language: bip39.Language.english,
    ));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not check Bitcoin transaction history.'),
      findsOneWidget,
    );
    expect(find.text('This wallet looks empty'), findsNothing);
    verifyNever(
      () => recover.execute(
        language: any(named: 'language'),
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      ),
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    verify(
      () => scan.execute(
        words: ['abandon'],
        language: bip39.Language.english,
        passphrase: ' pass ',
      ),
    ).called(2);
    await tester.tap(find.text('Continue without checking'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    verify(
      () => recover.execute(
        mnemonicWords: ['abandon'],
        language: bip39.Language.english,
        passphrase: ' pass ',
      ),
    ).called(1);
    recovery.complete(const Err(OnboardingWalletSetupFailure()));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    unawaited(bloc.close());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('a pending scan shows progress', (tester) async {
    const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => true);
    final pending = Completer<Result<bool, OnboardingFailure>>();
    final scan = _Scan();
    when(
      () => scan.execute(
        language: any(named: 'language'),
        words: any(named: 'words'),
        passphrase: any(named: 'passphrase'),
      ),
    ).thenAnswer((_) => pending.future);
    final bloc = OnboardingBloc(
      createWallet: () async => const Ok(null),
      recoverWallet: _Recover().execute,
      scanOnboardingWalletUsecase: scan,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: _delegates,
        supportedLocales: OnboardingLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: const OnboardingPhysicalRecovery(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).onSubmit((
      words: const ['abandon'],
      passphrase: 'pass',
      label: '',
      language: bip39.Language.english,
    ));
    await tester.pump();
    expect(
      tester
          .widget<BullFadingLinearProgress>(
            find.byType(BullFadingLinearProgress),
          )
          .trigger,
      isTrue,
    );
    pending.complete(const Err(OnboardingWalletScanFailure()));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    unawaited(bloc.close());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets('recovery without a passphrase does not scan or warn', (
    tester,
  ) async {
    const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => true);
    final recover = _Recover();
    final recovery = Completer<Result<void, OnboardingFailure>>();
    when(
      () => recover.execute(
        language: any(named: 'language'),
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      ),
    ).thenAnswer((_) => recovery.future);
    final scan = _Scan();
    when(
      () => scan.execute(
        language: any(named: 'language'),
        words: any(named: 'words'),
        passphrase: any(named: 'passphrase'),
      ),
    ).thenAnswer((_) async => const Ok(false));
    final bloc = OnboardingBloc(
      createWallet: () async => const Ok(null),
      recoverWallet: recover.execute,
      scanOnboardingWalletUsecase: scan,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: _delegates,
        supportedLocales: OnboardingLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: const OnboardingPhysicalRecovery(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).onSubmit((
      words: const ['abandon'],
      passphrase: '',
      label: '',
      language: bip39.Language.english,
    ));
    await tester.pump();
    verifyNever(
      () => scan.execute(
        language: any(named: 'language'),
        words: any(named: 'words'),
        passphrase: any(named: 'passphrase'),
      ),
    );
    verify(
      () => recover.execute(
        mnemonicWords: ['abandon'],
        language: bip39.Language.english,
        passphrase: '',
      ),
    ).called(1);
    expect(find.textContaining('This wallet looks empty'), findsNothing);
    recovery.complete(const Err(OnboardingWalletSetupFailure()));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    unawaited(bloc.close());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
