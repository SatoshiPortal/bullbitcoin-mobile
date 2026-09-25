import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_secret_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCompletePhysicalBackupVerificationUsecase extends Mock
    implements CompletePhysicalBackupVerificationUsecase {}

class _MockLoadWalletsForNetworkUsecase extends Mock
    implements LoadWalletsForNetworkUsecase {}

class _MockGetSecretFromFingerprintUsecase extends Mock
    implements GetSecretFromFingerprintUsecase {}

class _SeedableTestWalletBackupBloc extends TestWalletBackupBloc {
  _SeedableTestWalletBackupBloc({
    required super.completePhysicalBackupVerificationUsecase,
    required super.loadWalletsForNetworkUsecase,
    required super.getSecretFromFingerprintUsecase,
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
  late _MockCompletePhysicalBackupVerificationUsecase completeUsecase;
  late _MockLoadWalletsForNetworkUsecase loadWalletsUsecase;
  late _MockGetSecretFromFingerprintUsecase getSecretUsecase;

  setUp(() {
    completeUsecase = _MockCompletePhysicalBackupVerificationUsecase();
    loadWalletsUsecase = _MockLoadWalletsForNetworkUsecase();
    getSecretUsecase = _MockGetSecretFromFingerprintUsecase();
  });

  _SeedableTestWalletBackupBloc buildBloc() => _SeedableTestWalletBackupBloc(
    completePhysicalBackupVerificationUsecase: completeUsecase,
    loadWalletsForNetworkUsecase: loadWalletsUsecase,
    getSecretFromFingerprintUsecase: getSecretUsecase,
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

    test(
      'records the backup once the sealed challenge has judged it',
      () async {
        // The comparison no longer happens here: `MnemonicChallenge` runs it
        // through `Secret.verifyWords`, inside the package, and the event that
        // reaches this bloc carries no words at all. What is left to test is
        // the bookkeeping.
        when(() => completeUsecase.execute()).thenAnswer((_) async {});
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
        bloc.add(const VerifyPhysicalBackup());
        await expectation;

        verify(() => completeUsecase.execute()).called(1);
        await bloc.close();
      },
    );

    test('refuses to record a backup with no wallet selected', () async {
      final bloc = buildBloc();

      final expectation = expectLater(
        bloc.stream,
        emits(
          predicate<TestWalletBackupState>(
            (s) => s.statusError == 'No wallet selected',
          ),
        ),
      );
      bloc.add(const VerifyPhysicalBackup());
      await expectation;

      verifyNever(() => completeUsecase.execute());
      await bloc.close();
    });

    test('hands out a handle, never the words', () async {
      // The bloc cannot return a mnemonic any more: the usecase gives a
      // `Secret`, which carries a description and a reference. There is no
      // app-side path left that could put words in state.
      final bloc = buildBloc();
      bloc.seed(
        TestWalletBackupState(
          selectedWallet: _wallet(isDefault: true, origin: 'a'),
        ),
      );

      for (final word in _mnemonicWords) {
        expect(bloc.state.toString(), isNot(contains(word)));
      }
      expect(bloc.loadSelectedWalletSecret, isA<Function>());
      await bloc.close();
    });
  });
}
