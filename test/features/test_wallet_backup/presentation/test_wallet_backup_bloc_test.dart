import 'package:backups/testing.dart';
import 'package:primitives/primitives.dart'
    show Err, Ok, BitcoinNetwork, Fingerprint;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

BackupWallet _wallet({required bool isDefault, required String origin}) =>
    BackupWallet(
      id: origin,
      label: 'Test',
      network: BitcoinNetwork.mainnet,
      isDefault: isDefault,
      fingerprint: Fingerprint(_fingerprint),
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

  group('TestWalletBackupBloc', () {
    test('loads wallets and selects the default one', () async {
      final nonDefault = _wallet(isDefault: false, origin: 'a');
      final defaultWallet = _wallet(isDefault: true, origin: 'b');
      when(() => loadWalletsUsecase.execute())
          .thenAnswer((_) async => Ok([nonDefault, defaultWallet]));
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
    test('a failed secret read reaches neither state nor the failure it '
        'reports: the seed path must not leak into a snackbar', () async {
      // A raw reason of the shape the seed path could produce.
      when(() => getSecretUsecase.execute(_fingerprint)).thenAnswer(
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

      final result = await bloc.loadSelectedWalletSecret();

      expect(result, isA<Err<Object, TestWalletBackupFailure>>());
      // The secret-shaped reason stays in logMessage and out of state.
      for (final word in _mnemonicWords) {
        expect(bloc.state.toString(), isNot(contains(word)));
      }
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
