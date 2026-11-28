import 'package:all_seed_view/testing.dart';
import 'package:all_seed_view/setup.dart';
import 'package:swaps/swaps.dart';
import 'package:backups/testing.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';

import 'dart:async';
import 'dart:io';

import '../../../../support/inventory_fixture.dart';

import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullFadingLinearProgress, BullPinPad;

import 'package:access/access.dart';
import 'package:access/setup.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:primitives/primitives.dart'
    show Err, Ok, Result, BitcoinNetwork, Fingerprint;
import 'package:physical_backup_verification/physical_backup_verification.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _AllCubit extends Mock implements AllSeedViewCubit {}

class _SwapEngine extends Mock implements BoltzSwaps {}

class _MockCompleteBackupVerificationUsecase extends Mock
    implements CompleteBackupVerificationUsecase {
  int calls = 0;
  Result<void, TestWalletBackupFailure> result = const Ok(null);

  @override
  Future<Result<void, TestWalletBackupFailure>> execute(
    BackupWallet wallet,
    PhysicalBackupProof proof,
  ) async {
    calls++;
    return result;
  }
}

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

BackupWallet _wallet(String fingerprint) => BackupWallet(
  id: 'origin-$fingerprint',
  label: 'BackupWallet $fingerprint',
  network: BitcoinNetwork.mainnet,
  isDefault: false,
  fingerprint: Fingerprint(fingerprint),
);

late Secret _secretA;
late Secret _secretB;
late BackupWallet _walletA;
late BackupWallet _walletB;

TestWalletBackupState _selected(BackupWallet wallet) => TestWalletBackupState(
  wallets: [_walletA, _walletB],
  selectedWallet: wallet,
);

void main() {
  late _MockGetSecretFromFingerprintUsecase getSecretUsecase;
  late _SeedableTestWalletBackupBloc bloc;
  late _MockCompleteBackupVerificationUsecase completeUsecase;
  late Directory inventoryDirectory;
  late InventoryFixture inventoryFixture;

  setUp(() async {
    FakeSecureStoragePlatform().install();
    inventoryDirectory = await Directory.systemTemp.createTemp(
      'backup-access-',
    );
    inventoryFixture = await InventoryFixture.open(inventoryDirectory);
    final secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '/tmp',
    );
    _secretA = ((await secrets.import(
      words: _wordsA,
      language: Language.english,
    )) as Ok<Secret, SecretFailure>).value;
    _secretB = ((await secrets.import(
      words: _wordsB,
      language: Language.english,
    )) as Ok<Secret, SecretFailure>).value;
    _walletA = _wallet(_secretA.id.hex);
    _walletB = _wallet(_secretB.id.hex);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, (_) async => true);

    getSecretUsecase = _MockGetSecretFromFingerprintUsecase();
    completeUsecase = _MockCompleteBackupVerificationUsecase();
    bloc = _SeedableTestWalletBackupBloc(
      completeBackupVerificationUsecase: completeUsecase,
      loadWalletsForNetworkUsecase: _MockLoadWalletsForNetworkUsecase(),
      getSecretFromFingerprintUsecase: getSecretUsecase,
    );
  });

  tearDown(() async {
    await bloc.close();
    await inventoryFixture.close();
    await inventoryDirectory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, null);
  });

  void stubSecret(Secret secret) {
    when(() => getSecretUsecase.execute(secret.id.hex))
        .thenAnswer((_) async => Ok(secret));
  }

  Future<void> mountAccess(Secrets secrets) async {
    expect(await inventoryFixture.inventory.setCredential('1234'), isA<Ok>());
    final services = GetIt.asNewInstance()..registerSingleton(secrets);
    addTearDown(services.reset);
    AccessFeature.mount(
      services: services,
      inventory: inventoryFixture.inventory,
      onUnlocked: (_) {},
      onBackUp: (_) async {},
    );
  }

  Finder findUnlockTitle(WidgetTester tester) => find.text(
    AccessLocalizations.of(tester.element(find.byType(MnemonicView)))
        .appUnlockScreenTitle,
  );

  Future<void> openRevealGate(WidgetTester tester, Finder title) async {
    await tester.ensureVisible(find.text('Show passphrase'));
    await tester.tap(find.text('Show passphrase'));
    await tester.pumpAndSettle();
    expect(title, findsOneWidget);
  }

  Future<void> authorize(WidgetTester tester) async {
    for (final digit in [1, 2, 3, 4]) {
      tester.widget<BullPinPad>(find.byType(BullPinPad)).onDigit(digit);
      await tester.pump();
    }
    final context = tester.element(find.byType(BullPinPad));
    final label = AccessLocalizations.of(context).appUnlockButton;
    final unlock = find.byWidgetPredicate(
      (widget) => widget is BullButton && widget.label == label,
    );
    await pumpUntilInventoryReady(
      tester,
      () => !tester.widget<BullButton>(unlock).disabled,
    );
    tester.widget<BullButton>(unlock).onPressed();
    await pumpUntilInventoryReady(
      tester,
      () => find.byType(BullPinPad).evaluate().isEmpty,
    );
  }

  Future<void> pumpScreen(WidgetTester tester, {Widget? screen}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: [
            AllSeedViewLocalizations.delegate,
            ...appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<TestWalletBackupBloc>.value(
            value: bloc,
            child:
                screen ??
                VerifyMnemonicScreen(
                  onTestSucceeded: (_) {},
                  successImage: AssetImage(Assets.animations.successTick.path),
                ),
          ),
        ),
      );

  final spinner = find.byWidgetPredicate(
    (widget) => widget is BullFadingLinearProgress && widget.trigger,
  );

  // Secret operations complete off-isolate, so pump frames while letting the
  // real clock run. The challenge has a loading line. Passphrase verification
  // keeps the form visible, so its callers wait for the result in the UI.
  Future<void> flush(WidgetTester tester, {bool Function()? until}) async {
    final isReady = until ?? () => spinner.evaluate().isEmpty;
    final attempts = until == null ? 25 : 100;
    for (var i = 0; i < attempts; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (i >= 2 && isReady()) return;
    }
  }

  // The words are sealed inside `MnemonicChallenge` and carry no text the
  // test could look for: which wallet is on screen is read from the
  // challenge's key, which is that wallet's fingerprint.
  void expectChallengeFor(BackupWallet wallet, Matcher matcher) => expect(
    find.byKey(ValueKey<String?>(wallet.fingerprint?.hex)),
    matcher,
    reason: wallet.label,
  );

  // BullSnackBar is an overlay entry on a 3 second timer, not a Material
  // SnackBar. A test that triggers one must let that timer run out, or the
  // binding fails the test over a pending timer at teardown.
  Future<void> drainSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('uses the default wallet name in both mnemonic titles', (
    tester,
  ) async {
    final wallet = BackupWallet(
      id: _walletA.id,
      network: _walletA.network,
      isDefault: true,
      label: null,
      fingerprint: _walletA.fingerprint,
    );
    stubSecret(_secretA);
    bloc.seed(TestWalletBackupState(wallets: [wallet], selectedWallet: wallet));

    await pumpScreen(
      tester,
      screen: ShowMnemonicScreen(
        onTestSucceeded: (_) {},
        successImage: AssetImage(Assets.animations.successTick.path),
      ),
    );
    await tester.pump();
    String? title() =>
        (tester.widget<AppBar>(find.byType(AppBar)).title as Text).data;
    expect(title(), 'Test Secure Bitcoin');

    await pumpScreen(tester);
    await tester.pump();
    expect(title(), 'Test Secure Bitcoin');
  });

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
    final secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '/tmp',
    );
    final result = await tester.runAsync(
      () => secrets.import(
        words: _wordsA,
        passphrase: ' Mixed ',
        language: Language.english,
      ),
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
    final incorrectPassphrase = find.text('Incorrect passphrase.');
    await tester.tap(find.text('Continue'));
    await flush(tester, until: incorrectPassphrase.tryEvaluate);
    expect(incorrectPassphrase, findsOneWidget);
    expect(completeUsecase.calls, 0);

    final success = find.byType(BackupTestSuccessScreen);
    await tester.enterText(find.byType(TextField), ' Mixed ');
    await tester.tap(find.text('Continue'));
    await flush(tester, until: success.tryEvaluate);
    expect(success, findsOneWidget);
    expect(completeUsecase.calls, 1);
  });

  testWidgets('only the sealed verdict records a backup', (tester) async {
    stubSecret(_secretA);
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);
    final challenge = tester.widget<MnemonicChallenge>(
      find.byType(MnemonicChallenge),
    );
    challenge.onProgress?.call(12, 12);
    await tester.pump();
    expect(completeUsecase.calls, 0);

    challenge.onSolved();
    await flush(
      tester,
      until: find.byType(BackupTestSuccessScreen).tryEvaluate,
    );
    expect(find.byType(BackupTestSuccessScreen), findsOneWidget);
    expect(completeUsecase.calls, 1);
  });

  testWidgets('drops a verdict after the wallet selection is cleared', (
    tester,
  ) async {
    stubSecret(_secretA);
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);
    final challenge = tester.widget<MnemonicChallenge>(
      find.byType(MnemonicChallenge),
    );
    // Emit the new selection before the old widget gets a chance to rebuild.
    bloc.seed(bloc.state.copyWith(selectedWallet: null));
    challenge.onSolved();
    await tester.pump();
    expect(find.byType(BackupTestSuccessScreen), findsNothing);
    expect(completeUsecase.calls, 0);
    await drainSnackBar(tester);
  });

  testWidgets('drops a verdict for a different selected wallet', (
    tester,
  ) async {
    stubSecret(_secretA);
    stubSecret(_secretB);
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);
    final challenge = tester.widget<MnemonicChallenge>(
      find.byType(MnemonicChallenge),
    );
    bloc.seed(_selected(_walletB));
    challenge.onSolved();
    await tester.pump();
    expect(find.byType(BackupTestSuccessScreen), findsNothing);
    expect(completeUsecase.calls, 0);
    await drainSnackBar(tester);
  });

  testWidgets('a failed write does not report success', (tester) async {
    stubSecret(_secretA);
    completeUsecase.result = const Err(TestWalletBackupCompletionFailure());
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);
    tester.widget<MnemonicChallenge>(find.byType(MnemonicChallenge)).onSolved();
    await tester.pump();
    expect(find.byType(BackupTestSuccessScreen), findsNothing);
    expect(completeUsecase.calls, 1);
    await drainSnackBar(tester);
  });

  testWidgets('a protected backup offers explicit passphrase reveal', (
    tester,
  ) async {
    Device.screen = const Size(800, 600);
    final secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '/tmp',
    );
    await tester.runAsync(() => mountAccess(secrets));
    final result = await tester.runAsync(
      () => secrets.import(
        words: _wordsA,
        passphrase: ' Mixed ',
        language: Language.english,
      ),
    );
    final secret = (result as Ok<Secret, SecretFailure>).value;
    final wallet = _wallet(secret.id.hex);
    stubSecret(secret);
    bloc.seed(_selected(wallet));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: [
          AllSeedViewLocalizations.delegate,
          ...appLocalizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<TestWalletBackupBloc>.value(
          value: bloc,
          child: ShowMnemonicScreen(
            successImage: AssetImage(Assets.animations.successTick.path),
            onTestSucceeded: (_) {},
          ),
        ),
      ),
    );
    await flush(tester);
    final pinTitle = findUnlockTitle(tester);
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
    await openRevealGate(tester, pinTitle);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(pinTitle, findsNothing);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
      isFalse,
    );
    await openRevealGate(tester, pinTitle);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await authorize(tester);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
      isFalse,
    );
    await openRevealGate(tester, pinTitle);
    stubSecret(_secretB);
    bloc.seed(_selected(_walletB));
    await authorize(tester);
    await tester.pump();
    await flush(tester);
    expect(
      tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
      isFalse,
    );
    bloc.seed(_selected(wallet));
    await flush(tester);
    await openRevealGate(tester, pinTitle);
    await authorize(tester);
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
      final secrets = Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => '/tmp',
      );
      await tester.runAsync(() => mountAccess(secrets));
      final result = await tester.runAsync(
        () => secrets.import(
          words: _wordsA,
          passphrase: ' Mixed ',
          language: Language.english,
        ),
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
          localizationsDelegates: [
            AllSeedViewLocalizations.delegate,
            ...appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<AllSeedViewCubit>.value(
            value: cubit,
            child: AllSeedViewScreen(
              access: const Access(),
              swaps: _SwapEngine(),
            ),
          ),
        ),
      );
      await flush(tester);
      final pinTitle = findUnlockTitle(tester);
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
      await openRevealGate(tester, pinTitle);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await authorize(tester);
      await tester.pumpAndSettle();
      expect(pinTitle, findsNothing);
      await flush(tester);
      expect(
        tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
        isFalse,
      );
      await openRevealGate(tester, pinTitle);
      await authorize(tester);
      await tester.pumpAndSettle();
      expect(pinTitle, findsNothing);
      await flush(tester);
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
    verify(() => getSecretUsecase.execute(_secretA.id.hex)).called(1);
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
      _selected(_walletA)
          .copyWith(verificationStatus: BackupVerificationStatus.failure),
    );
    await flush(tester);

    verify(() => getSecretUsecase.execute(_secretA.id.hex)).called(1);
    expectChallengeFor(_walletA, findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('drops a load overtaken by a later wallet switch', (
    tester,
  ) async {
    // BackupWallet A's read is held open until after wallet B's has landed, so the
    // stale result arrives last and must not replace B's words.
    final slowReadOfA = Completer<_SecretResult>();
    when(() => getSecretUsecase.execute(_secretA.id.hex))
        .thenAnswer((_) => slowReadOfA.future);
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
    when(() => getSecretUsecase.execute(_secretB.id.hex)).thenAnswer(
      (_) async => const Err(TestWalletBackupSeedUnavailableFailure()),
    );
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);

    bloc.seed(_selected(_walletB));
    await flush(tester);

    // BackupWallet A's challenge must not sit under wallet B's name, and the screen
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
