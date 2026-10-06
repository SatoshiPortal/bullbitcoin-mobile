import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/verify_physical_backup_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/test_wallet_backup_failure_l10n.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/verify_mnemonic_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCompleteBackupVerificationUsecase extends Mock
    implements CompleteBackupVerificationUsecase {}

class _MockLoadWalletsForNetworkUsecase extends Mock
    implements LoadWalletsForNetworkUsecase {}

class _MockGetMnemonicFromFingerprintUsecase extends Mock
    implements GetMnemonicFromFingerprintUsecase {}

class _MockVerifyPhysicalBackupUsecase extends Mock
    implements VerifyPhysicalBackupUsecase {}

/// Lets a test put the bloc into an exact state, standing in for the
/// asynchronous `LoadWallets` and a wallet switch from the picker.
class _SeedableTestWalletBackupBloc extends TestWalletBackupBloc {
  _SeedableTestWalletBackupBloc({
    required super.completeBackupVerificationUsecase,
    required super.loadWalletsForNetworkUsecase,
    required super.getMnemonicFromFingerprintUsecase,
    required super.verifyPhysicalBackupUsecase,
  });

  void seed(TestWalletBackupState state) => emit(state);
}

typedef _MnemonicResult =
    Result<(List<String>, String?), TestWalletBackupFailure>;

/// The `no_screenshot` plugin behind `PrivacyScreen` talks over this channel;
/// answering it keeps the screen's privacy future from failing in tests.
const _noScreenshotChannel = MethodChannel(
  'com.flutterplaza.no_screenshot_methods',
);

const _fingerprintA = 'aaaa1111';
const _fingerprintB = 'bbbb2222';

// Two word lists with no word in common, so a word on screen identifies the
// wallet it belongs to without ambiguity.
const _wordsA = [
  'legal',
  'winner',
  'thank',
  'year',
  'wave',
  'sausage',
  'worth',
  'useful',
  'abandon',
  'ability',
  'able',
  'about',
];
const _wordsB = [
  'raise',
  'beach',
  'verb',
  'shell',
  'soft',
  'tumble',
  'satoshi',
  'wink',
  'clown',
  'enjoy',
  'more',
  'senior',
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
  late _MockGetMnemonicFromFingerprintUsecase getMnemonicUsecase;
  late _SeedableTestWalletBackupBloc bloc;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, (_) async => true);

    getMnemonicUsecase = _MockGetMnemonicFromFingerprintUsecase();
    bloc = _SeedableTestWalletBackupBloc(
      completeBackupVerificationUsecase:
          _MockCompleteBackupVerificationUsecase(),
      loadWalletsForNetworkUsecase: _MockLoadWalletsForNetworkUsecase(),
      getMnemonicFromFingerprintUsecase: getMnemonicUsecase,
      verifyPhysicalBackupUsecase: _MockVerifyPhysicalBackupUsecase(),
    );
  });

  tearDown(() async {
    await bloc.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, null);
  });

  void stubMnemonic(String fingerprint, List<String> words) {
    when(
      () => getMnemonicUsecase.execute(fingerprint),
    ).thenAnswer((_) async => Ok((words, null)));
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
  // the listener and the awaited mnemonic read.
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  }

  void expectWords(List<String> words, Matcher matcher) {
    for (final word in words) {
      expect(find.text(word), matcher, reason: word);
    }
  }

  // SnackBarUtils is an overlay entry on a 3 second timer, not a Material
  // SnackBar. A test that triggers one must let that timer run out, or the
  // binding fails the test over a pending timer at teardown.
  Future<void> drainSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  final spinner = find.byType(CircularProgressIndicator);

  testWidgets('loads the words once the wallet arrives after mount', (
    tester,
  ) async {
    stubMnemonic(_fingerprintA, _wordsA);

    // The test flow opens this screen while LoadWallets is still running, so
    // there is no selected wallet yet and nothing to show but the spinner.
    await pumpScreen(tester);
    await flush(tester);
    expect(spinner, findsOneWidget);
    verifyNever(() => getMnemonicUsecase.execute(any()));

    bloc.seed(_selected(_walletA));
    await flush(tester);

    expect(spinner, findsNothing);
    expectWords(_wordsA, findsOneWidget);
  });

  testWidgets('loads the words at once when a wallet is already selected', (
    tester,
  ) async {
    stubMnemonic(_fingerprintA, _wordsA);
    bloc.seed(_selected(_walletA));

    await pumpScreen(tester);
    await flush(tester);

    expect(spinner, findsNothing);
    expectWords(_wordsA, findsOneWidget);
    verify(() => getMnemonicUsecase.execute(_fingerprintA)).called(1);
  });

  testWidgets('reloads the words when the selected wallet changes', (
    tester,
  ) async {
    stubMnemonic(_fingerprintA, _wordsA);
    stubMnemonic(_fingerprintB, _wordsB);
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);

    bloc.seed(_selected(_walletB));
    await flush(tester);

    expectWords(_wordsB, findsOneWidget);
    expectWords(_wordsA, findsNothing);
  });

  testWidgets('does not reload for a state change that keeps the wallet', (
    tester,
  ) async {
    stubMnemonic(_fingerprintA, _wordsA);
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);

    bloc.seed(
      _selected(
        _walletA,
      ).copyWith(verificationStatus: BackupVerificationStatus.failure),
    );
    await flush(tester);

    verify(() => getMnemonicUsecase.execute(_fingerprintA)).called(1);
    expectWords(_wordsA, findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('drops a load overtaken by a later wallet switch', (
    tester,
  ) async {
    // Wallet A's read is held open until after wallet B's has landed, so the
    // stale result arrives last and must not replace B's words.
    final slowReadOfA = Completer<_MnemonicResult>();
    when(
      () => getMnemonicUsecase.execute(_fingerprintA),
    ).thenAnswer((_) => slowReadOfA.future);
    stubMnemonic(_fingerprintB, _wordsB);

    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);
    expect(spinner, findsOneWidget);

    bloc.seed(_selected(_walletB));
    await flush(tester);
    expectWords(_wordsB, findsOneWidget);

    slowReadOfA.complete(const Ok((_wordsA, null)));
    await flush(tester);

    expectWords(_wordsB, findsOneWidget);
    expectWords(_wordsA, findsNothing);
  });

  testWidgets('clears the previous words when the new wallet read fails', (
    tester,
  ) async {
    stubMnemonic(_fingerprintA, _wordsA);
    when(() => getMnemonicUsecase.execute(_fingerprintB)).thenAnswer(
      (_) async => const Err(TestWalletBackupSeedUnavailableFailure()),
    );
    bloc.seed(_selected(_walletA));
    await pumpScreen(tester);
    await flush(tester);

    bloc.seed(_selected(_walletB));
    await flush(tester);

    // Wallet A's words must not sit under wallet B's name, and the screen
    // must not fall back to the spinner either.
    expectWords(_wordsA, findsNothing);
    expect(spinner, findsNothing);
    final context = tester.element(find.byType(VerifyMnemonicScreen));
    expect(
      find.text(
        const TestWalletBackupSeedUnavailableFailure().toTranslated(context),
      ),
      findsOneWidget,
    );
    await drainSnackBar(tester);
  });
}
