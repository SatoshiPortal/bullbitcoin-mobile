import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_secret_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart' show Secret;

class _MockCompleteBackupVerificationUsecase extends Mock
    implements CompleteBackupVerificationUsecase {}

class _MockLoadWalletsForNetworkUsecase extends Mock
    implements LoadWalletsForNetworkUsecase {}

class _MockGetSecretFromFingerprintUsecase extends Mock
    implements GetSecretFromFingerprintUsecase {}

class _SeedableTestWalletBackupBloc extends TestWalletBackupBloc {
  _SeedableTestWalletBackupBloc({
    required super.completeBackupVerificationUsecase,
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
  late _MockCompleteBackupVerificationUsecase completeUsecase;
  late _MockLoadWalletsForNetworkUsecase loadWalletsUsecase;
  late _MockGetSecretFromFingerprintUsecase getSecretUsecase;

  setUp(() {
    completeUsecase = _MockCompleteBackupVerificationUsecase();
    loadWalletsUsecase = _MockLoadWalletsForNetworkUsecase();
    getSecretUsecase = _MockGetSecretFromFingerprintUsecase();
  });

  _SeedableTestWalletBackupBloc buildBloc() => _SeedableTestWalletBackupBloc(
    completeBackupVerificationUsecase: completeUsecase,
    loadWalletsForNetworkUsecase: loadWalletsUsecase,
    getSecretFromFingerprintUsecase: getSecretUsecase,
  );

  _SeedableTestWalletBackupBloc seeded() => buildBloc()
    ..seed(
      TestWalletBackupState(
        selectedWallet: _wallet(isDefault: true, origin: 'a'),
      ),
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
      'records the backup once the sealed challenge has judged it',
      () async {
        // The comparison no longer happens here: `MnemonicChallenge` runs it
        // through `secret.verify.mnemonic`, inside the package, and the event
        // that reaches this bloc carries no words at all. What is left to test
        // is the bookkeeping.
        when(
          () => completeUsecase.execute(masterFingerprint: _fingerprint),
        ).thenAnswer((_) async => const Ok(null));
        final bloc = seeded();

        final expectation = expectLater(
          bloc.stream,
          emits(
            predicate<TestWalletBackupState>(
              (s) => s.verificationStatus == BackupVerificationStatus.success,
            ),
          ),
        );
        bloc.add(const VerifyPhysicalBackup(masterFingerprint: _fingerprint));
        await expectation;

        verify(
          () => completeUsecase.execute(masterFingerprint: _fingerprint),
        ).called(1);
        await bloc.close();
      },
    );

    test('reports a verification that could not be recorded', () async {
      when(
        () => completeUsecase.execute(masterFingerprint: _fingerprint),
      ).thenAnswer((_) async => const Err(TestWalletBackupCompletionFailure()));
      final bloc = seeded();

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
      bloc.add(const VerifyPhysicalBackup(masterFingerprint: _fingerprint));
      await expectation;
      await bloc.close();
    });

    test('refuses to record a backup with no wallet selected', () async {
      final bloc = buildBloc();

      final expectation = expectLater(
        bloc.stream,
        emits(
          predicate<TestWalletBackupState>(
            (s) => s.failure is TestWalletBackupNoWalletSelectedFailure,
          ),
        ),
      );
      bloc.add(const VerifyPhysicalBackup(masterFingerprint: _fingerprint));
      await expectation;

      verifyNever(
        () => completeUsecase.execute(masterFingerprint: _fingerprint),
      );
      await bloc.close();
    });

    test('rejects a solved challenge from a previous wallet', () async {
      when(
        () => completeUsecase.execute(
          masterFingerprint: any(named: 'masterFingerprint'),
        ),
      ).thenAnswer((_) async => const Ok(null));
      final bloc = seeded();
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
      bloc.add(const VerifyPhysicalBackup(masterFingerprint: 'ffffffff'));
      await expectation;
      verifyNever(
        () => completeUsecase.execute(
          masterFingerprint: any(named: 'masterFingerprint'),
        ),
      );
      await bloc.close();
    });

    test(
      'a pending failure cannot overwrite a newer wallet selection',
      () async {
        final entered = Completer<void>();
        final pending = Completer<Result<void, TestWalletBackupFailure>>();
        when(
          () => completeUsecase.execute(masterFingerprint: _fingerprint),
        ).thenAnswer((_) {
          entered.complete();
          return pending.future;
        });
        final bloc = seeded();
        bloc.add(const VerifyPhysicalBackup(masterFingerprint: _fingerprint));
        await entered.future;
        final newer = _wallet(
          isDefault: false,
          origin: 'b',
        ).copyWith(masterFingerprint: 'ffffffff');
        final selected = bloc.stream.firstWhere(
          (state) => state.selectedWallet?.masterFingerprint == 'ffffffff',
        );
        bloc.add(WalletSelected(wallet: newer));
        await selected;
        pending.complete(const Err(TestWalletBackupCompletionFailure()));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.selectedWallet, newer);
        expect(bloc.state.failure, isNull);
        expect(bloc.state.verificationStatus, BackupVerificationStatus.idle);
        await bloc.close();
      },
    );

    test('hands out a handle, never the words', () async {
      // The bloc cannot return a mnemonic any more: the usecase gives a
      // `Secret`, which carries a description and a reference. There is no
      // app-side path left that could put words in state.
      final bloc = seeded();

      for (final word in _mnemonicWords) {
        expect(bloc.state.toString(), isNot(contains(word)));
      }
      expect(
        bloc.loadSelectedWalletSecret,
        isA<Future<Result<Secret, TestWalletBackupFailure>> Function()>(),
      );
      await bloc.close();
    });

    test('a failed secret read reaches neither state nor a message', () async {
      when(() => getSecretUsecase.execute(_fingerprint)).thenAnswer(
        (_) async => const Err(TestWalletBackupSeedUnavailableFailure()),
      );
      final bloc = seeded();

      final result = await bloc.loadSelectedWalletSecret();

      expect(
        result,
        isA<Err<Secret, TestWalletBackupFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<TestWalletBackupSeedUnavailableFailure>(),
        ),
      );
      expect(bloc.state.failure, isNull);
      await bloc.close();
    });

    test(
      'loading the secret without a selected wallet is a typed failure',
      () async {
        final bloc = buildBloc();

        final result = await bloc.loadSelectedWalletSecret();

        expect(
          result,
          isA<Err<Secret, TestWalletBackupFailure>>().having(
            (e) => e.failure,
            'failure',
            isA<TestWalletBackupNoWalletSelectedFailure>(),
          ),
        );
        verifyNever(() => getSecretUsecase.execute(any()));
        await bloc.close();
      },
    );
  });
}
