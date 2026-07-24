import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWallet extends Mock implements Wallet {}

class MockImportWalletUsecase extends Mock implements ImportWalletUsecase {}

class MockCheckWalletStatusUsecase extends Mock
    implements CheckWalletStatusUsecase {}

class MockCheckDuplicateMnemonicUsecase extends Mock
    implements CheckDuplicateMnemonicUsecase {}

class MockCheckCompactBlockFiltersAvailableUsecase extends Mock
    implements CheckCompactBlockFiltersAvailableUsecase {}

// A valid 12-word BIP-39 mnemonic (test vector, no secret material) used
// only to get `ImportMnemonicCubit.updateMnemonic`'s internal script-type
// scan past its own word-count validation.
const _validWords = [
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

void main() {
  late MockImportWalletUsecase importWallet;
  late MockCheckWalletStatusUsecase checkWalletStatus;
  late MockCheckDuplicateMnemonicUsecase checkDuplicate;
  late MockCheckCompactBlockFiltersAvailableUsecase
  checkCompactBlockFiltersAvailable;

  setUpAll(() {
    registerFallbackValue(ScriptType.bip84);
  });

  ImportMnemonicCubit buildCubit() => ImportMnemonicCubit(
    importWalletUsecase: importWallet,
    checkWalletUsecase: checkWalletStatus,
    checkDuplicateMnemonicUsecase: checkDuplicate,
    checkCompactBlockFiltersAvailableUsecase: checkCompactBlockFiltersAvailable,
  );

  setUp(() {
    importWallet = MockImportWalletUsecase();
    checkWalletStatus = MockCheckWalletStatusUsecase();
    checkDuplicate = MockCheckDuplicateMnemonicUsecase();
    checkCompactBlockFiltersAvailable =
        MockCheckCompactBlockFiltersAvailableUsecase();
  });

  group('ImportMnemonicCubit guards', () {
    test(
      'updateMnemonic with empty label emits ImportMnemonicEmptyLabelFailure — no usecase called',
      () async {
        final cubit = buildCubit();

        await cubit.updateMnemonic((
          label: '',
          passphrase: '',
          words: const <String>[],
          language: bip39.Language.english,
        ));

        expect(cubit.state.failure, isA<ImportMnemonicEmptyLabelFailure>());
        verifyNever(
          () => checkDuplicate.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            passphrase: any(named: 'passphrase'),
          ),
        );

        cubit.close();
      },
    );

    test(
      'import with no mnemonic set emits ImportMnemonicNullMnemonicFailure — no usecase called',
      () async {
        final cubit = buildCubit();

        await cubit.import();

        expect(cubit.state.failure, isA<ImportMnemonicNullMnemonicFailure>());
        verifyNever(
          () => importWallet.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            label: any(named: 'label'),
          ),
        );

        cubit.close();
      },
    );

    test('clearFailure resets failure to null', () async {
      final cubit = buildCubit();

      await cubit.import();
      expect(cubit.state.failure, isNotNull);

      cubit.clearFailure();
      expect(cubit.state.failure, isNull);

      cubit.close();
    });
  });

  group('ImportMnemonicCubit sync backend & birthday', () {
    test('init() loads isCbfAvailable from the usecase', () async {
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);
      final cubit = buildCubit();

      await cubit.init();

      expect(cubit.state.isCbfAvailable, isTrue);
      cubit.close();
    });

    test('selectSyncBackend updates state and clears any failure', () async {
      final cubit = buildCubit();
      await cubit.import(); // sets a failure (no mnemonic)
      expect(cubit.state.failure, isNotNull);

      cubit.selectSyncBackend(BitcoinSyncBackend.compactBlockFilters);

      expect(cubit.state.syncBackend, BitcoinSyncBackend.compactBlockFilters);
      expect(cubit.state.failure, isNull);
      cubit.close();
    });

    test('updateBirthday updates state and clears any failure', () async {
      final cubit = buildCubit();
      await cubit.import(); // sets a failure (no mnemonic)
      final date = DateTime.utc(2022, 6, 1);

      cubit.updateBirthday(date);

      expect(cubit.state.birthday, date);
      expect(cubit.state.failure, isNull);
      cubit.close();
    });

    test(
      'import forwards the selected syncBackend and birthday to the usecase',
      () async {
        final cubit = buildCubit();
        final wallet = MockWallet();
        when(
          () => checkDuplicate.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            passphrase: any(named: 'passphrase'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        await cubit.updateMnemonic((
          label: 'My wallet',
          passphrase: '',
          words: _validWords,
          language: bip39.Language.english,
        ));
        cubit.selectSyncBackend(BitcoinSyncBackend.compactBlockFilters);
        final date = DateTime.utc(2022, 6, 1);
        cubit.updateBirthday(date);
        when(
          () => importWallet.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            label: any(named: 'label'),
            passphrase: any(named: 'passphrase'),
            scriptType: any(named: 'scriptType'),
            requestedSyncBackend: any(named: 'requestedSyncBackend'),
            birthday: any(named: 'birthday'),
          ),
        ).thenAnswer((_) async => Ok(wallet));

        await cubit.import();

        verify(
          () => importWallet.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            label: any(named: 'label'),
            passphrase: any(named: 'passphrase'),
            scriptType: any(named: 'scriptType'),
            requestedSyncBackend: BitcoinSyncBackend.compactBlockFilters,
            birthday: date,
          ),
        ).called(1);
        cubit.close();
      },
    );

    test('retryImportWithGenesisBirthday resets the birthday to null and '
        'retries the import', () async {
      final cubit = buildCubit();
      final wallet = MockWallet();
      when(
        () => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => const Ok(null));
      await cubit.updateMnemonic((
        label: 'My wallet',
        passphrase: '',
        words: _validWords,
        language: bip39.Language.english,
      ));
      cubit.selectSyncBackend(BitcoinSyncBackend.compactBlockFilters);
      cubit.updateBirthday(DateTime.utc(2022, 6, 1));
      when(
        () => importWallet.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          label: any(named: 'label'),
          passphrase: any(named: 'passphrase'),
          scriptType: any(named: 'scriptType'),
          requestedSyncBackend: any(named: 'requestedSyncBackend'),
          birthday: any(named: 'birthday'),
        ),
      ).thenAnswer((_) async => Ok(wallet));

      await cubit.retryImportWithGenesisBirthday();

      expect(cubit.state.birthday, isNull);
      verify(
        () => importWallet.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          label: any(named: 'label'),
          passphrase: any(named: 'passphrase'),
          scriptType: any(named: 'scriptType'),
          requestedSyncBackend: BitcoinSyncBackend.compactBlockFilters,
          birthday: null,
        ),
      ).called(1);
      cubit.close();
    });
  });
}
