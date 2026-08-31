import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/verify_physical_backup_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCompletePhysicalBackupVerificationUsecase extends Mock
    implements CompletePhysicalBackupVerificationUsecase {}

class _MockLoadWalletsForNetworkUsecase extends Mock
    implements LoadWalletsForNetworkUsecase {}

class _MockGetMnemonicFromFingerprintUsecase extends Mock
    implements GetMnemonicFromFingerprintUsecase {}

class _MockVerifyPhysicalBackupUsecase extends Mock
    implements VerifyPhysicalBackupUsecase {}

class _SeedableTestWalletBackupBloc extends TestWalletBackupBloc {
  _SeedableTestWalletBackupBloc({
    required super.completePhysicalBackupVerificationUsecase,
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
  publicDescriptor: 'wpkh([abcd1234/84h/0h/0h]xpub/<0;1>/*)',
  signers: [
    WalletSigner.single(
      masterFingerprint: _fingerprint,
      xpubFingerprint: _fingerprint,
      xpub: 'xpub',
      derivationPath: "m/84'/0'/0'",
      signer: SignerEntity.local,
      signerDevice: null,
    ),
  ],
  scriptType: ScriptType.bip84,
  balanceSat: BigInt.zero,
);

void main() {
  late _MockCompletePhysicalBackupVerificationUsecase completeUsecase;
  late _MockLoadWalletsForNetworkUsecase loadWalletsUsecase;
  late _MockGetMnemonicFromFingerprintUsecase getMnemonicUsecase;
  late _MockVerifyPhysicalBackupUsecase verifyUsecase;

  setUp(() {
    completeUsecase = _MockCompletePhysicalBackupVerificationUsecase();
    loadWalletsUsecase = _MockLoadWalletsForNetworkUsecase();
    getMnemonicUsecase = _MockGetMnemonicFromFingerprintUsecase();
    verifyUsecase = _MockVerifyPhysicalBackupUsecase();
  });

  _SeedableTestWalletBackupBloc buildBloc() => _SeedableTestWalletBackupBloc(
    completePhysicalBackupVerificationUsecase: completeUsecase,
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
      ).thenAnswer((_) async => [nonDefault, defaultWallet]);
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

    test('selects the wallet that owns a requested seed fingerprint', () async {
      final defaultWallet = _wallet(isDefault: true, origin: 'a');
      final requestedWallet = Wallet(
        origin: 'b',
        label: 'Requested',
        network: Network.bitcoinMainnet,
        publicDescriptor: 'wpkh([beef1234/84h/0h/0h]xpub/<0;1>/*)',
        signers: [
          WalletSigner.single(
            masterFingerprint: 'beef1234',
            xpubFingerprint: 'beef1234',
            xpub: 'xpub',
            derivationPath: "m/84'/0'/0'",
            signer: SignerEntity.local,
            signerDevice: null,
          ),
        ],
        scriptType: ScriptType.bip84,
        balanceSat: BigInt.zero,
      );
      when(
        () => loadWalletsUsecase.execute(),
      ).thenAnswer((_) async => [defaultWallet, requestedWallet]);
      final bloc = buildBloc();

      final expectation = expectLater(
        bloc.stream,
        emits(
          predicate<TestWalletBackupState>(
            (state) => state.selectedWallet == requestedWallet,
          ),
        ),
      );
      bloc.add(const LoadWallets(fingerprint: 'BEEF1234'));
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
        ).thenAnswer((_) async => true);
        when(
          () => completeUsecase.execute(fingerprint: _fingerprint),
        ).thenAnswer((_) async {});
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
        verify(
          () => completeUsecase.execute(fingerprint: _fingerprint),
        ).called(1);
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
        ).thenAnswer((_) async => false);
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

        verifyNever(
          () => completeUsecase.execute(fingerprint: any(named: 'fingerprint')),
        );
        await bloc.close();
      },
    );

    test('never exposes the secret through state or toString', () async {
      when(
        () => getMnemonicUsecase.execute(_fingerprint),
      ).thenAnswer((_) async => (_mnemonicWords, 'secret-passphrase'));
      final bloc = buildBloc();
      bloc.seed(
        TestWalletBackupState(
          selectedWallet: _wallet(isDefault: true, origin: 'a'),
        ),
      );

      final (words, passphrase) = await bloc.loadSelectedWalletMnemonic();

      expect(words, _mnemonicWords);
      expect(passphrase, 'secret-passphrase');
      for (final word in _mnemonicWords) {
        expect(bloc.state.toString(), isNot(contains(word)));
      }
      expect(bloc.state.toString(), isNot(contains('secret-passphrase')));
      await bloc.close();
    });
  });
}
