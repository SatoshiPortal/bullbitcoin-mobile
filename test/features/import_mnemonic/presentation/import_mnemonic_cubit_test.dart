import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockImportWalletUsecase extends Mock implements ImportWalletUsecase {}

class MockCheckWalletStatusUsecase extends Mock
    implements CheckWalletStatusUsecase {}

class MockCheckDuplicateMnemonicUsecase extends Mock
    implements CheckDuplicateMnemonicUsecase {}

void main() {
  late MockImportWalletUsecase importWallet;
  late MockCheckWalletStatusUsecase checkWalletStatus;
  late MockCheckDuplicateMnemonicUsecase checkDuplicate;

  ImportMnemonicCubit buildCubit() => ImportMnemonicCubit(
    importWalletUsecase: importWallet,
    checkWalletUsecase: checkWalletStatus,
    checkDuplicateMnemonicUsecase: checkDuplicate,
  );

  setUp(() {
    importWallet = MockImportWalletUsecase();
    checkWalletStatus = MockCheckWalletStatusUsecase();
    checkDuplicate = MockCheckDuplicateMnemonicUsecase();
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
}
