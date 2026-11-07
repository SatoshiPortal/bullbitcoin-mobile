import 'dart:async';

import 'package:bb_mobile/features/import_mnemonic/domain/check_wallet_status_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart'
    show ScriptType, Wallet;

class MockWallet extends Mock implements Wallet {}

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

  test('accepts a Japanese vector before scanning', () async {
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    final cubit = ImportMnemonicCubit(
      importWalletUsecase: importWallet,
      checkWalletUsecase: checkWalletStatus,
      checkDuplicateMnemonicUsecase: CheckDuplicateMnemonicUsecase(
        secrets: secrets,
      ),
    );
    addTearDown(cubit.close);
    final mnemonic = (
      label: 'Japanese vector',
      passphrase: '',
      words: [...List.filled(11, 'あいこくしん'), 'あおぞら'],
      language: bip39.Language.japanese,
    );
    await cubit.updateMnemonic(mnemonic);
    expect(cubit.state.failure, isNull);
    expect(cubit.state.mnemonic, mnemonic);
  });

  for (final language in bip39.Language.values) {
    test(
      'forwards ${language.name} to duplicate check, scan and import',
      () async {
        final mnemonic = (
          label: 'Vector',
          passphrase: 'TREZOR',
          words: bip39.Mnemonic(List.filled(16, 0), language).words,
          language: language,
        );
        final wallet = MockWallet();
        when(
          () => checkDuplicate.execute(
            mnemonicWords: mnemonic.words,
            language: language,
            passphrase: mnemonic.passphrase,
          ),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => checkWalletStatus(
            words: mnemonic.words,
            language: language,
            passphrase: mnemonic.passphrase,
            scriptTypes: {ScriptType.bip84, ScriptType.bip49, ScriptType.bip44},
          ),
        ).thenAnswer((_) async => {});
        when(
          () => importWallet.execute(
            mnemonicWords: mnemonic.words,
            language: language,
            passphrase: mnemonic.passphrase,
            label: mnemonic.label,
            scriptType: ScriptType.bip84,
          ),
        ).thenAnswer((_) async => Ok(wallet));
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.updateMnemonic(mnemonic);
        await pumpEventQueue();
        expect(cubit.state.failure, isNull);
        await cubit.import();
        expect(cubit.state.wallet, wallet);
        verify(
          () => checkDuplicate.execute(
            mnemonicWords: mnemonic.words,
            language: language,
            passphrase: mnemonic.passphrase,
          ),
        ).called(1);
        verify(
          () => checkWalletStatus(
            words: mnemonic.words,
            language: language,
            passphrase: mnemonic.passphrase,
            scriptTypes: {ScriptType.bip84, ScriptType.bip49, ScriptType.bip44},
          ),
        ).called(1);
        verify(
          () => importWallet.execute(
            mnemonicWords: mnemonic.words,
            language: language,
            passphrase: mnemonic.passphrase,
            label: mnemonic.label,
            scriptType: ScriptType.bip84,
          ),
        ).called(1);
      },
    );
  }

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
