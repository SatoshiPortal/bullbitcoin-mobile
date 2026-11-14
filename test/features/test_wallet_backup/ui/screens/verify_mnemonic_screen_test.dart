import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/all_seed_view/ui/all_seed_view_screen.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:bb_mobile/features/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_secret_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/test_wallet_backup_failure_l10n.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/verify_mnemonic_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/show_mnemonic_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _AllCubit extends Mock implements AllSeedViewCubit {}

class _RevealUnlock extends AppUnlockFacade {
  const _RevealUnlock();

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
        child: const Text('Authenticate reveal'),
      ),
    );
  }
}

class _MockCompleteBackupVerificationUsecase extends Mock
    implements CompleteBackupVerificationUsecase {}

class _MockLoadWalletsForNetworkUsecase extends Mock
    implements LoadWalletsForNetworkUsecase {}

class _MockGetSecretFromFingerprintUsecase extends Mock
    implements GetSecretFromFingerprintUsecase {}

/// Lets a test put the bloc into an exact state, standing in for the
/// asynchronous `LoadWallets` and a wallet switch from the picker.
class _SeedableTestWalletBackupBloc extends TestWalletBackupBloc {
  _SeedableTestWalletBackupBloc({
    required super.completeBackupVerificationUsecase,
    required super.loadWalletsForNetworkUsecase,
    required super.getSecretFromFingerprintUsecase,
  });

  void seed(TestWalletBackupState state) => emit(state);
}

typedef _SecretResult = Result<Secret, TestWalletBackupFailure>;

/// The `no_screenshot` plugin behind `PrivacyScreen` talks over this channel;
/// answering it keeps the screen's privacy future from failing in tests.
const _noScreenshotChannel = MethodChannel(
  'com.flutterplaza.no_screenshot_methods',
);

// Two BIP39 test vectors with no word in common.
const _wordsA = [
  'legal',
  'winner',
  'thank',
  'year',
  'wave',
  'sausage',
  'worth',
  'useful',
  'legal',
  'winner',
  'thank',
  'yellow',
];
const _wordsB = [
  'letter',
  'advice',
  'cage',
  'absurd',
  'amount',
  'doctor',
  'acoustic',
  'avoid',
  'letter',
  'advice',
  'cage',
  'above',
];

Wallet _wallet(String fingerprint) => Wallet(
  origin: 'origin-$fingerprint',
  label: 'Wallet $fingerprint',
  network: Network.bitcoinMainnet,
  isDefault: false,
  masterFingerprint: fingerprint,
  xpubFingerprint: fingerprint,
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'desc',
  internalPublicDescriptor: 'desc',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

late Secret _secretA;
late Secret _secretB;
late Wallet _walletA;
late Wallet _walletB;

TestWalletBackupState _selected(Wallet wallet) => TestWalletBackupState(
  wallets: [_walletA, _walletB],
  selectedWallet: wallet,
);

void main() {
  late _MockGetSecretFromFingerprintUsecase getSecretUsecase;
  late _SeedableTestWalletBackupBloc bloc;
  late _MockCompleteBackupVerificationUsecase completeUsecase;

  setUp(() async {
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    _secretA =
        ((await secrets.import(words: _wordsA)) as Ok<Secret, SecretFailure>)
            .value;
    _secretB =
        ((await secrets.import(words: _wordsB)) as Ok<Secret, SecretFailure>)
            .value;
    _walletA = _wallet(_secretA.id.hex);
    _walletB = _wallet(_secretB.id.hex);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, (_) async => true);

    getSecretUsecase = _MockGetSecretFromFingerprintUsecase();
    completeUsecase = _MockCompleteBackupVerificationUsecase();
    when(
      () => completeUsecase.execute(),
    ).thenAnswer((_) async => const Ok(null));
    bloc = _SeedableTestWalletBackupBloc(
      completeBackupVerificationUsecase: completeUsecase,
      loadWalletsForNetworkUsecase: _MockLoadWalletsForNetworkUsecase(),
      getSecretFromFingerprintUsecase: getSecretUsecase,
    );
  });

  tearDown(() async {
    await bloc.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, null);
  });

  void stubSecret(Secret secret) {
    when(
      () => getSecretUsecase.execute(secret.id.hex),
    ).thenAnswer((_) async => Ok(secret));
  }

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<TestWalletBackupBloc>.value(
        value: bloc,
        child: const VerifyMnemonicScreen(),
      ),
    ),
  );

  // The spinner animates forever, so pumpAndSettle would never return while
  // it is on screen. The challenge reads its words inside the package, which
  // does real asynchronous work (PBKDF2), so frames alternate with the real
  // clock until no spinner is left, within a bound generous enough for a
  // suite running in parallel.
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (i >= 2 && find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        return;
      }
    }
  }

  // The words are sealed inside `MnemonicChallenge` and carry no text the
  // test could look for: which wallet is on screen is read from the
  // challenge's key, which is that wallet's fingerprint.
  void expectChallengeFor(Wallet wallet, Matcher matcher) => expect(
    find.byKey(ValueKey<String?>(wallet.masterFingerprint)),
    matcher,
    reason: wallet.label,
  );

  // SnackBarUtils is an overlay entry on a 3 second timer, not a Material
  // SnackBar. A test that triggers one must let that timer run out, or the
  // binding fails the test over a pending timer at teardown.
  Future<void> drainSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  final spinner = find.byType(CircularProgressIndicator);

  testWidgets('loads a wallet selected while screen protection is pending', (
    tester,
  ) async {
    final protection = Completer<bool>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _noScreenshotChannel,
      (call) async => call.method == 'screenshotOff' ? protection.future : true,
    );
    stubSecret(_secretA);
    await pumpScreen(tester);
    await tester.pump();
    bloc.seed(_selected(_walletA));
    await tester.pump();
    expect(find.byType(MnemonicChallenge), findsNothing);
    protection.complete(true);
    await flush(tester);
    expect(find.byType(MnemonicChallenge), findsOneWidget);
    expectChallengeFor(_walletA, findsOneWidget);
  });

  testWidgets('asks for the passphrase before recording a backup', (
    tester,
  ) async {
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    final result = await tester.runAsync(
      () => secrets.import(words: _wordsA, passphrase: ' Mixed '),
    );
    final secret = (result as Ok<Secret, SecretFailure>).value;
    final wallet = _wallet(secret.id.hex);
    stubSecret(secret);
    bloc.seed(_selected(wallet));
    await pumpScreen(tester);
    await flush(tester);

    tester.widget<MnemonicChallenge>(find.byType(MnemonicChallenge)).onSolved();
    await tester.pump();
    expect(
      find.text('Enter your passphrase to verify your backup.'),
      findsOneWidget,
    );
    expect(
      bloc.state.verificationStatus,
      isNot(BackupVerificationStatus.success),
    );

    await tester.enterText(find.byType(TextField), 'temporary');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.enterText(find.byType(TextField), 'Mixed');
    await tester.tap(find.text('Continue'));
    await flush(tester);
    expect(find.text('Incorrect passphrase.'), findsOneWidget);
    verifyNever(() => completeUsecase.execute());

    await tester.enterText(find.byType(TextField), ' Mixed ');
    await tester.tap(find.text('Continue'));
    await flush(tester);
    verify(() => completeUsecase.execute()).called(1);
  });

  testWidgets('a protected backup offers explicit passphrase reveal', (
    tester,
  ) async {
    Device.screen = const Size(800, 600);
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    final result = await tester.runAsync(
      () => secrets.import(words: _wordsA, passphrase: ' Mixed '),
    );
    final secret = (result as Ok<Secret, SecretFailure>).value;
    final wallet = _wallet(secret.id.hex);
    stubSecret(secret);
    bloc.seed(_selected(wallet));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<TestWalletBackupBloc>.value(
          value: bloc,
          child: const ShowMnemonicScreen(appUnlockFacade: _RevealUnlock()),
        ),
      ),
    );
    await flush(tester);
    expect(find.text('Show passphrase'), findsOneWidget);
    expect(
      find.text(
        'These words alone cannot restore this wallet. Keep your passphrase separately.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
      isFalse,
    );
    await tester.ensureVisible(find.text('Show passphrase'));
    await tester.tap(find.text('Show passphrase'));
    await tester.pumpAndSettle();
    expect(find.text('Authenticate reveal'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
      isFalse,
    );
    await tester.ensureVisible(find.text('Show passphrase'));
    await tester.tap(find.text('Show passphrase'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.text('Authenticate reveal'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
      isFalse,
    );
    await tester.ensureVisible(find.text('Show passphrase'));
    await tester.tap(find.text('Show passphrase'));
    await tester.pumpAndSettle();
    stubSecret(_secretB);
    bloc.seed(_selected(_walletB));
    await tester.tap(find.text('Authenticate reveal'));
    await tester.pump();
    await flush(tester);
    expect(
      tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
      isFalse,
    );
    bloc.seed(_selected(wallet));
    await flush(tester);
    await tester.ensureVisible(find.text('Show passphrase'));
    await tester.tap(find.text('Show passphrase'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Authenticate reveal'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
      isTrue,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(
      tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
      isFalse,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets(
    'all seeds offers explicit passphrase reveal and hides it on pause',
    (tester) async {
      final secrets = Secrets(scratchDirectory: () async => '/tmp');
      final result = await tester.runAsync(
        () => secrets.import(words: _wordsA, passphrase: ' Mixed '),
      );
      final secret = (result as Ok<Secret, SecretFailure>).value;
      final cubit = _AllCubit();
      when(() => cubit.state).thenReturn(
        AllSeedViewState(
          isUnlocked: true,
          loading: false,
          seedsVisible: true,
          existingWallets: [secret],
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<AllSeedViewCubit>.value(
            value: cubit,
            child: const AllSeedViewScreen(appUnlockFacade: _RevealUnlock()),
          ),
        ),
      );
      await flush(tester);
      expect(find.text('Show passphrase'), findsOneWidget);
      expect(
        find.text(
          'These words alone cannot restore this wallet. Keep your passphrase separately.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
        isFalse,
      );
      await tester.ensureVisible(find.text('Show passphrase'));
      await tester.tap(find.text('Show passphrase'));
      await tester.pumpAndSettle();
      expect(find.text('Authenticate reveal'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.text('Authenticate reveal'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
        isFalse,
      );
      await tester.ensureVisible(find.text('Show passphrase'));
      await tester.tap(find.text('Show passphrase'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Authenticate reveal'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
        isTrue,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(
        tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
        isFalse,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets('loads the words once the wallet arrives after mount', (
    tester,
  ) async {
    stubSecret(_secretA);

    // The test flow opens this screen while LoadWallets is still running, so
    // there is no selected wallet yet and nothing to show but the spinner.
    await pumpScreen(tester);
    await flush(tester);
    expect(spinner, findsOneWidget);
    verifyNever(() => getSecretUsecase.execute(any()));

    bloc.seed(_selected(_walletA));
    await flush(tester);

    expect(spinner, findsNothing);
    expectChallengeFor(_walletA, findsOneWidget);
  });

  testWidgets('loads the words at once when a wallet is already selected', (
    tester,
  ) async {
    stubSecret(_secretA);
    bloc.seed(_selected(_walletA));

    await pumpScreen(tester);
    await flush(tester);

    expect(spinner, findsNothing);
    expectChallengeFor(_walletA, findsOneWidget);
    verify(
      () => getSecretUsecase.execute(_walletA.masterFingerprint),
    ).called(1);
  });

  testWidgets('reloads the words when the selected wallet changes', (
    tester,
  ) async {
    stubSecret(_secretA);
    stubSecret(_secretB);
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);

    bloc.seed(_selected(_walletB));
    await flush(tester);

    expectChallengeFor(_walletB, findsOneWidget);
    expectChallengeFor(_walletA, findsNothing);
  });

  testWidgets('does not reload for a state change that keeps the wallet', (
    tester,
  ) async {
    stubSecret(_secretA);
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);

    bloc.seed(
      _selected(
        _walletA,
      ).copyWith(verificationStatus: BackupVerificationStatus.failure),
    );
    await flush(tester);

    verify(
      () => getSecretUsecase.execute(_walletA.masterFingerprint),
    ).called(1);
    expectChallengeFor(_walletA, findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('drops a load overtaken by a later wallet switch', (
    tester,
  ) async {
    // Wallet A's read is held open until after wallet B's has landed, so the
    // stale result arrives last and must not replace B's words.
    final slowReadOfA = Completer<_SecretResult>();
    when(
      () => getSecretUsecase.execute(_walletA.masterFingerprint),
    ).thenAnswer((_) => slowReadOfA.future);
    stubSecret(_secretB);

    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);
    expect(spinner, findsOneWidget);

    bloc.seed(_selected(_walletB));
    await flush(tester);
    expectChallengeFor(_walletB, findsOneWidget);

    slowReadOfA.complete(Ok(_secretA));
    await flush(tester);

    expectChallengeFor(_walletB, findsOneWidget);
    expectChallengeFor(_walletA, findsNothing);
  });

  testWidgets('clears the previous words when the new wallet read fails', (
    tester,
  ) async {
    stubSecret(_secretA);
    when(() => getSecretUsecase.execute(_walletB.masterFingerprint)).thenAnswer(
      (_) async => const Err(TestWalletBackupSeedUnavailableFailure()),
    );
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);

    bloc.seed(_selected(_walletB));
    await flush(tester);

    // Wallet A's challenge must not sit under wallet B's name, and the screen
    // must not fall back to the spinner either.
    expectChallengeFor(_walletA, findsNothing);
    expect(spinner, findsNothing);
    final context = tester.element(find.byType(VerifyMnemonicScreen));
    expect(
      find.text(
        const TestWalletBackupSeedUnavailableFailure().toTranslated(context),
      ),
      findsOneWidget,
    );
    // An empty word list is a failed read, not a finished test.
    expect(find.text(context.loc.testBackupAllWordsSelected), findsNothing);
    await drainSnackBar(tester);
  });

  testWidgets('ends the spinner when the wallets fail to load', (tester) async {
    await pumpScreen(tester);
    await flush(tester);
    expect(spinner, findsOneWidget);

    // LoadWallets failed: no wallet will ever be selected, so no read is
    // coming that would end the spinner.
    bloc.seed(
      const TestWalletBackupState(
        failure: TestWalletBackupWalletsUnavailableFailure(),
      ),
    );
    await flush(tester);

    expect(spinner, findsNothing);
    verifyNever(() => getSecretUsecase.execute(any()));
    final context = tester.element(find.byType(VerifyMnemonicScreen));
    expect(
      find.text(
        const TestWalletBackupWalletsUnavailableFailure().toTranslated(context),
      ),
      findsOneWidget,
    );
    expect(find.text(context.loc.testBackupAllWordsSelected), findsNothing);
    await drainSnackBar(tester);
  });
}
