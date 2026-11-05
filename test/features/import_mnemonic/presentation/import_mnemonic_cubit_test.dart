import 'dart:async';

import 'package:bb_mobile/features/import_mnemonic/domain/check_wallet_status_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart'
    show ScriptType;

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

  group('ImportMnemonicCubit scan', () {
    const status = (satoshis: 1000, transactions: 1);
    final mnemonic = (
      label: 'wallet',
      passphrase: 'TREZOR',
      words: const ['abandon', 'about'],
      language: bip39.Language.english,
    );

    setUpAll(() {
      registerFallbackValue(bip39.Language.english);
      registerFallbackValue(<ScriptType>{});
    });

    setUp(() {
      when(
        () => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => const Ok(null));
    });

    test(
      'requests the three script types in one call and emits each scan',
      () async {
        final bip49 = Completer<({BigInt satoshis, int transactions})>();
        final bip44 = Completer<({BigInt satoshis, int transactions})>();
        when(
          () => checkWalletStatus(
            words: any(named: 'words'),
            language: any(named: 'language'),
            passphrase: any(named: 'passphrase'),
            scriptTypes: any(named: 'scriptTypes'),
          ),
        ).thenAnswer(
          (_) async => {
            ScriptType.bip84: Future.value((
              satoshis: BigInt.from(status.satoshis),
              transactions: status.transactions,
            )),
            ScriptType.bip49: bip49.future,
            ScriptType.bip44: bip44.future,
          },
        );
        final cubit = buildCubit();

        await cubit.updateMnemonic(mnemonic);
        await pumpEventQueue();
        bip44.completeError(Exception('scan failed'));
        await pumpEventQueue();

        // The pending bip49 scan does not hold back bip84; the failed bip44 scan is not surfaced.
        expect(cubit.state.bip84Status?.satoshis, BigInt.from(status.satoshis));
        expect(cubit.state.bip49Status, isNull);
        expect(cubit.state.bip44Status, isNull);
        expect(cubit.state.failure, isNull);

        bip49.complete((satoshis: BigInt.zero, transactions: 0));
        await pumpEventQueue();
        expect(cubit.state.bip49Status?.transactions, 0);

        verify(
          () => checkWalletStatus(
            words: mnemonic.words,
            language: bip39.Language.english,
            passphrase: 'TREZOR',
            scriptTypes: {ScriptType.bip84, ScriptType.bip49, ScriptType.bip44},
          ),
        ).called(1);

        await cubit.close();
      },
    );

    test('a failed derivation leaves every status empty', () async {
      when(
        () => checkWalletStatus(
          words: any(named: 'words'),
          language: any(named: 'language'),
          passphrase: any(named: 'passphrase'),
          scriptTypes: any(named: 'scriptTypes'),
        ),
      ).thenThrow(CheckWalletStatusException('derivation failed'));
      final cubit = buildCubit();

      await cubit.updateMnemonic(mnemonic);
      await pumpEventQueue();

      expect(cubit.state.mnemonic, mnemonic);
      expect(cubit.state.bip84Status, isNull);
      expect(cubit.state.bip49Status, isNull);
      expect(cubit.state.bip44Status, isNull);
      expect(cubit.state.failure, isNull);

      await cubit.close();
    });
  });
}
