import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_secret_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/test_wallet_backup_failure_l10n.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/verify_mnemonic_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

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

const _fingerprintA = 'aaaa1111';
const _fingerprintB = 'bbbb2222';

// BIP39 test vectors: two real secrets, so the screen shows a real sealed
// challenge. The words are painted, not text, so a test tells the wallets
// apart by the secret the challenge was given, never by reading a word.
const _wordsA = [
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'about',
];
const _wordsB = [
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

final _walletA = _wallet(_fingerprintA);
final _walletB = _wallet(_fingerprintB);

TestWalletBackupState _selected(Wallet wallet) => TestWalletBackupState(
  wallets: [_walletA, _walletB],
  selectedWallet: wallet,
);

void main() {
  late Secret secretA;
  late Secret secretB;
  late _MockGetSecretFromFingerprintUsecase getSecretUsecase;
  late _SeedableTestWalletBackupBloc bloc;

  setUpAll(() async {
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    secretA =
        ((await secrets.import(words: _wordsA)) as Ok<Secret, SecretFailure>)
            .value;
    secretB =
        ((await secrets.import(words: _wordsB)) as Ok<Secret, SecretFailure>)
            .value;
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, (_) async => true);

    getSecretUsecase = _MockGetSecretFromFingerprintUsecase();
    bloc = _SeedableTestWalletBackupBloc(
      completeBackupVerificationUsecase:
          _MockCompleteBackupVerificationUsecase(),
      loadWalletsForNetworkUsecase: _MockLoadWalletsForNetworkUsecase(),
      getSecretFromFingerprintUsecase: getSecretUsecase,
    );
  });

  tearDown(() async {
    await bloc.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, null);
  });

  void stubSecret(String fingerprint, Secret secret) {
    when(
      () => getSecretUsecase.execute(fingerprint),
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
  // it is on screen. A few plain frames are enough to flush the bloc stream,
  // the listener and the awaited secret read.
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  }

  /// The secret the sealed challenge on screen was handed, if any.
  Secret? shownSecret(WidgetTester tester) {
    final challenges = find.byType(MnemonicChallenge);
    if (challenges.evaluate().isEmpty) return null;
    return tester.widget<MnemonicChallenge>(challenges).secret;
  }

  // SnackBarUtils is an overlay entry on a 3 second timer, not a Material
  // SnackBar. A test that triggers one must let that timer run out, or the
  // binding fails the test over a pending timer at teardown.
  Future<void> drainSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  final spinner = find.byType(CircularProgressIndicator);

  testWidgets('loads the secret once the wallet arrives after mount', (
    tester,
  ) async {
    stubSecret(_fingerprintA, secretA);

    // The test flow opens this screen while LoadWallets is still running, so
    // there is no selected wallet yet and nothing to show but the spinner.
    await pumpScreen(tester);
    await flush(tester);
    expect(spinner, findsOneWidget);
    verifyNever(() => getSecretUsecase.execute(any()));

    bloc.seed(_selected(_walletA));
    await flush(tester);

    expect(shownSecret(tester)?.id, secretA.id);
  });

  testWidgets('loads the secret at once when a wallet is already selected', (
    tester,
  ) async {
    stubSecret(_fingerprintA, secretA);
    bloc.seed(_selected(_walletA));

    await pumpScreen(tester);
    await flush(tester);

    expect(shownSecret(tester)?.id, secretA.id);
    verify(() => getSecretUsecase.execute(_fingerprintA)).called(1);
  });

  testWidgets('reloads the secret when the selected wallet changes', (
    tester,
  ) async {
    stubSecret(_fingerprintA, secretA);
    stubSecret(_fingerprintB, secretB);
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);

    bloc.seed(_selected(_walletB));
    await flush(tester);

    expect(shownSecret(tester)?.id, secretB.id);
  });

  testWidgets('does not reload for a state change that keeps the wallet', (
    tester,
  ) async {
    stubSecret(_fingerprintA, secretA);
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);

    bloc.seed(
      _selected(
        _walletA,
      ).copyWith(verificationStatus: BackupVerificationStatus.failure),
    );
    await flush(tester);

    verify(() => getSecretUsecase.execute(_fingerprintA)).called(1);
    expect(shownSecret(tester)?.id, secretA.id);
  });

  testWidgets('drops a load overtaken by a later wallet switch', (
    tester,
  ) async {
    // Wallet A's read is held open until after wallet B's has landed, so the
    // stale result arrives last and must not replace B's challenge.
    final slowReadOfA = Completer<_SecretResult>();
    when(
      () => getSecretUsecase.execute(_fingerprintA),
    ).thenAnswer((_) => slowReadOfA.future);
    stubSecret(_fingerprintB, secretB);

    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);
    expect(spinner, findsOneWidget);

    bloc.seed(_selected(_walletB));
    await flush(tester);
    expect(shownSecret(tester)?.id, secretB.id);

    slowReadOfA.complete(Ok(secretA));
    await flush(tester);

    expect(shownSecret(tester)?.id, secretB.id);
  });

  testWidgets('clears the previous challenge when the new wallet read fails', (
    tester,
  ) async {
    stubSecret(_fingerprintA, secretA);
    when(() => getSecretUsecase.execute(_fingerprintB)).thenAnswer(
      (_) async => const Err(TestWalletBackupSeedUnavailableFailure()),
    );
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);

    bloc.seed(_selected(_walletB));
    await flush(tester);

    // Wallet A's challenge must not sit under wallet B's name, and the
    // screen must not fall back to the spinner either.
    expect(shownSecret(tester), isNull);
    expect(spinner, findsNothing);
    final context = tester.element(find.byType(VerifyMnemonicScreen));
    expect(
      find.text(
        const TestWalletBackupSeedUnavailableFailure().toTranslated(context),
      ),
      findsOneWidget,
    );
    // A failed read is not a finished test.
    expect(find.text(context.loc.testBackupAllWordsSelected), findsNothing);
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
