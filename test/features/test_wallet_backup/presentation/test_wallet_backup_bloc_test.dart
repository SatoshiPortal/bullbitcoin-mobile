import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/verify_physical_backup_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
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

class _SeedableTestWalletBackupBloc extends TestWalletBackupBloc {
  _SeedableTestWalletBackupBloc({
    required super.completeBackupVerificationUsecase,
    required super.loadWalletsForNetworkUsecase,
    required super.getMnemonicFromFingerprintUsecase,
    required super.verifyPhysicalBackupUsecase,
  });

  void seed(TestWalletBackupState state) => emit(state);
}

const _fingerprint = 'abcd1234';
const _mnemonicWords = [
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
  'yes',
];

Wallet _wallet({required bool isDefault, required String origin}) => Wallet(
  origin: origin,
  label: 'Test',
  network: Network.bitcoinMainnet,
  isDefault: isDefault,
  masterFingerprint: _fingerprint,
  xpubFingerprint: _fingerprint,
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'desc',
  internalPublicDescriptor: 'desc',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

void main() {
  late _MockCompleteBackupVerificationUsecase completeUsecase;
  late _MockLoadWalletsForNetworkUsecase loadWalletsUsecase;
  late _MockGetMnemonicFromFingerprintUsecase getMnemonicUsecase;
  late _MockVerifyPhysicalBackupUsecase verifyUsecase;

  setUp(() {
    completeUsecase = _MockCompleteBackupVerificationUsecase();
    loadWalletsUsecase = _MockLoadWalletsForNetworkUsecase();
    getMnemonicUsecase = _MockGetMnemonicFromFingerprintUsecase();
    verifyUsecase = _MockVerifyPhysicalBackupUsecase();
  });

  _SeedableTestWalletBackupBloc buildBloc() => _SeedableTestWalletBackupBloc(
    completeBackupVerificationUsecase: completeUsecase,
    loadWalletsForNetworkUsecase: loadWalletsUsecase,
    getMnemonicFromFingerprintUsecase: getMnemonicUsecase,
    verifyPhysicalBackupUsecase: verifyUsecase,
  );

  group('TestWalletBackupBloc', () {
    test('loads wallets and selects the default one', () async {
      final nonDefault = _wallet(isDefault: false, origin: 'a');
      final defaultWallet = _wallet(isDefault: true, origin: 'b');
      when(
        () => loadWalletsUsecase.execute(),
      ).thenAnswer((_) async => Ok([nonDefault, defaultWallet]));
      final bloc = buildBloc();

      final expectation = expectLater(
        bloc.stream,
        emits(
          predicate<TestWalletBackupState>(
            (s) => s.wallets.length == 2 && s.selectedWallet == defaultWallet,
          ),
        ),
      );
      bloc.add(const LoadWallets());
      await expectation;
      await bloc.close();
    });

    test(
      'emits success and completes the backup when words are correct',
      () async {
        when(
          () => verifyUsecase.execute(
            fingerprint: _fingerprint,
            mnemonic: _mnemonicWords,
          ),
        ).thenAnswer((_) async => const Ok(true));
        when(
          () => completeUsecase.execute(),
        ).thenAnswer((_) async => const Ok(null));
        final bloc = buildBloc();
        bloc.seed(
          TestWalletBackupState(
            selectedWallet: _wallet(isDefault: true, origin: 'a'),
          ),
        );

        final expectation = expectLater(
          bloc.stream,
          emits(
            predicate<TestWalletBackupState>(
              (s) => s.verificationStatus == BackupVerificationStatus.success,
            ),
          ),
        );
        bloc.add(const VerifyPhysicalBackup(reorderedWords: _mnemonicWords));
        await expectation;

        verify(
          () => verifyUsecase.execute(
            fingerprint: _fingerprint,
            mnemonic: _mnemonicWords,
          ),
        ).called(1);
        verify(() => completeUsecase.execute()).called(1);
        await bloc.close();
      },
    );

    test(
      'emits failure and does not complete the backup when words are wrong',
      () async {
        when(
          () => verifyUsecase.execute(
            fingerprint: any(named: 'fingerprint'),
            mnemonic: any(named: 'mnemonic'),
          ),
        ).thenAnswer((_) async => const Ok(false));
        final bloc = buildBloc();
        bloc.seed(
          TestWalletBackupState(
            selectedWallet: _wallet(isDefault: true, origin: 'a'),
          ),
        );

        final expectation = expectLater(
          bloc.stream,
          emits(
            predicate<TestWalletBackupState>(
              (s) => s.verificationStatus == BackupVerificationStatus.failure,
            ),
          ),
        );
        bloc.add(const VerifyPhysicalBackup(reorderedWords: _mnemonicWords));
        await expectation;

        verifyNever(() => completeUsecase.execute());
        await bloc.close();
      },
    );

    test('never exposes the secret through state or toString', () async {
      when(() => getMnemonicUsecase.execute(_fingerprint)).thenAnswer(
        (_) async => const Ok((_mnemonicWords, 'secret-passphrase')),
      );
      final bloc = buildBloc();
      bloc.seed(
        TestWalletBackupState(
          selectedWallet: _wallet(isDefault: true, origin: 'a'),
        ),
      );

      final result = await bloc.loadSelectedWalletMnemonic();

      final (
        words,
        passphrase,
      ) = (result as Ok<(List<String>, String?), TestWalletBackupFailure>)
          .value;
      expect(words, _mnemonicWords);
      expect(passphrase, 'secret-passphrase');
      for (final word in _mnemonicWords) {
        expect(bloc.state.toString(), isNot(contains(word)));
      }
      expect(bloc.state.toString(), isNot(contains('secret-passphrase')));
      await bloc.close();
    });

    test('a failed secret read reaches neither state nor the failure it '
        'reports: the seed path must not leak into a snackbar', () async {
      // A raw reason of the shape the seed path could produce.
      when(() => getMnemonicUsecase.execute(_fingerprint)).thenAnswer(
        (_) async => const Err(
          TestWalletBackupSeedUnavailableFailure(
            'keychain: legal winner thank year',
          ),
        ),
      );
      final bloc = buildBloc();
      bloc.seed(
        TestWalletBackupState(
          selectedWallet: _wallet(isDefault: true, origin: 'a'),
        ),
      );

      final result = await bloc.loadSelectedWalletMnemonic();

      expect(
        result,
        isA<Err<(List<String>, String?), TestWalletBackupFailure>>(),
      );
      // The secret-shaped reason stays in logMessage and out of state.
      for (final word in _mnemonicWords) {
        expect(bloc.state.toString(), isNot(contains(word)));
      }
      await bloc.close();
    });

    test(
      'reports a wrong mnemonic as a verification result, not a failure',
      () async {
        when(
          () => verifyUsecase.execute(
            fingerprint: _fingerprint,
            mnemonic: _mnemonicWords,
          ),
        ).thenAnswer((_) async => const Ok(false));
        final bloc = buildBloc();
        bloc.seed(
          TestWalletBackupState(
            selectedWallet: _wallet(isDefault: true, origin: 'a'),
          ),
        );

        final expectation = expectLater(
          bloc.stream,
          emits(
            predicate<TestWalletBackupState>(
              (s) =>
                  s.verificationStatus == BackupVerificationStatus.failure &&
                  s.failure == null,
            ),
          ),
        );
        bloc.add(const VerifyPhysicalBackup(reorderedWords: _mnemonicWords));
        await expectation;
        verifyNever(() => completeUsecase.execute());
        await bloc.close();
      },
    );

    test('reports a failed completion instead of claiming success', () async {
      when(
        () => verifyUsecase.execute(
          fingerprint: _fingerprint,
          mnemonic: _mnemonicWords,
        ),
      ).thenAnswer((_) async => const Ok(true));
      when(() => completeUsecase.execute()).thenAnswer(
        (_) async =>
            const Err(TestWalletBackupCompletionFailure('drift: locked')),
      );
      final bloc = buildBloc();
      bloc.seed(
        TestWalletBackupState(
          selectedWallet: _wallet(isDefault: true, origin: 'a'),
        ),
      );

      final expectation = expectLater(
        bloc.stream,
        emits(
          predicate<TestWalletBackupState>(
            (s) =>
                s.failure is TestWalletBackupCompletionFailure &&
                s.verificationStatus != BackupVerificationStatus.success,
          ),
        ),
      );
      bloc.add(const VerifyPhysicalBackup(reorderedWords: _mnemonicWords));
      await expectation;
      await bloc.close();
    });

    test('surfaces a typed failure when no wallet is selected', () async {
      final bloc = buildBloc();

      final expectation = expectLater(
        bloc.stream,
        emits(
          predicate<TestWalletBackupState>(
            (s) => s.failure is TestWalletBackupNoWalletSelectedFailure,
          ),
        ),
      );
      bloc.add(const VerifyPhysicalBackup(reorderedWords: _mnemonicWords));
      await expectation;
      await bloc.close();
    });

    test(
      'surfaces a typed failure when the wallet list cannot be loaded',
      () async {
        when(() => loadWalletsUsecase.execute()).thenAnswer(
          (_) async => const Err(
            TestWalletBackupWalletsUnavailableFailure('drift: locked'),
          ),
        );
        final bloc = buildBloc();

        final expectation = expectLater(
          bloc.stream,
          emits(
            predicate<TestWalletBackupState>(
              (s) => s.failure is TestWalletBackupWalletsUnavailableFailure,
            ),
          ),
        );
        bloc.add(const LoadWallets());
        await expectation;
        await bloc.close();
      },
    );
  });
}
