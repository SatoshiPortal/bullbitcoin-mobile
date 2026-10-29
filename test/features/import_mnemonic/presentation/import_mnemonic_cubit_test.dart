import 'dart:async';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/discover_mnemonic_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
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

class _Wallet extends Mock implements Wallet {}

void main() {
  late MockImportWalletUsecase importWallet;
  late MockCheckWalletStatusUsecase checkWalletStatus;
  late MockCheckDuplicateMnemonicUsecase checkDuplicate;
  final publicFixture = bip39.Mnemonic(
    List.filled(16, 0),
    bip39.Language.english,
  );

  setUpAll(() {
    registerFallbackValue(publicFixture);
    registerFallbackValue(ScriptType.bip84);
  });

  Future<void> enterWords(ImportMnemonicCubit cubit) async {
    when(
      () => checkDuplicate.execute(
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    await cubit.updateMnemonic((
      label: 'Public BIP39 vector',
      passphrase: '',
      words: publicFixture.words,
      language: bip39.Language.english,
    ));
  }

  ImportMnemonicCubit buildCubit() => ImportMnemonicCubit(
    importWalletUsecase: importWallet,
    discovery: DiscoverMnemonicWalletsUsecase(check: checkWalletStatus),
    checkDuplicateMnemonicUsecase: checkDuplicate,
  );

  setUp(() {
    importWallet = MockImportWalletUsecase();
    checkWalletStatus = MockCheckWalletStatusUsecase();
    checkDuplicate = MockCheckDuplicateMnemonicUsecase();
  });

  group('ImportMnemonicCubit guards', () {
    test(
      'private import forwards birthday and script; retry requires a fresh source choice',
      () async {
        final birthday = WalletBirthday(DateTime.utc(2021, 3));
        when(
          () => importWallet.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            label: 'Public BIP39 vector',
            passphrase: '',
            scriptType: ScriptType.bip49,
            birthday: birthday,
            bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
          ),
        ).thenAnswer((_) async => const Err(ImportMnemonicUnexpectedFailure()));
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await enterWords(cubit);
        await cubit.confirmSource(
          source: BitcoinSyncSource.compactBlockFilters,
          birthday: birthday,
          scriptType: ScriptType.bip49,
        );
        await cubit.import();
        verify(
          () => importWallet.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            label: 'Public BIP39 vector',
            passphrase: '',
            scriptType: ScriptType.bip49,
            birthday: birthday,
            bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
          ),
        ).called(1);
        var sawEmpty = false;
        final subscription = cubit.stream.listen((state) {
          if (state.mnemonic == null) sawEmpty = true;
        });
        await enterWords(cubit);
        await pumpEventQueue();
        await subscription.cancel();
        expect(sawEmpty, isTrue);
        expect(cubit.state.sourceConfirmed, isFalse);
        verifyZeroInteractions(checkWalletStatus);
      },
    );

    test(
      'reset during import ignores the old completion and duplicate submit',
      () async {
        final pending = Completer<Result<Wallet, ImportMnemonicFailure>>();
        when(
          () => importWallet.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            label: 'Public BIP39 vector',
            passphrase: '',
            scriptType: ScriptType.bip84,
            bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
          ),
        ).thenAnswer((_) => pending.future);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await enterWords(cubit);
        await cubit.confirmSource(
          source: BitcoinSyncSource.compactBlockFilters,
        );
        final importing = cubit.import();
        await cubit.import();
        cubit.reset();
        pending.complete(Ok(_Wallet()));
        await importing;
        expect(cubit.state.wallet, isNull);
        expect(cubit.state.mnemonic, isNull);
        verify(
          () => importWallet.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            label: 'Public BIP39 vector',
            passphrase: '',
            scriptType: ScriptType.bip84,
            bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
          ),
        ).called(1);
      },
    );

    test(
      'CBF confirmation never calls Electrum; Native SegWit remains default',
      () async {
        final cubit = buildCubit();
        await enterWords(cubit);
        await cubit.confirmSource(
          source: BitcoinSyncSource.compactBlockFilters,
        );
        expect(cubit.state.scriptType, ScriptType.bip84);
        expect(cubit.state.sourceConfirmed, isTrue);
        expect(cubit.state.birthday, isNull);
        verifyZeroInteractions(checkWalletStatus);
        await cubit.close();
      },
    );

    test(
      'explicit Electrum keeps three previews and reset rejects late results',
      () async {
        final pending = Completer<MnemonicWalletPreview>();
        when(
          () => checkWalletStatus(
            mnemonic: any(named: 'mnemonic'),
            scriptType: any(named: 'scriptType'),
          ),
        ).thenAnswer((_) => pending.future);
        final cubit = buildCubit();
        await enterWords(cubit);
        final discovery = cubit.confirmSource(
          source: BitcoinSyncSource.electrum,
        );
        verify(
          () => checkWalletStatus(
            mnemonic: any(named: 'mnemonic'),
            scriptType: any(named: 'scriptType'),
          ),
        ).called(3);
        cubit.reset();
        pending.complete((satoshis: BigInt.one, transactions: 1));
        await discovery;
        expect(cubit.state.mnemonic, isNull);
        expect(cubit.state.bip84Status, isNull);
        expect(cubit.state.bip49Status, isNull);
        expect(cubit.state.bip44Status, isNull);
        await cubit.close();
      },
    );

    test('confirmed source is required before wallet creation', () async {
      final cubit = buildCubit();
      await enterWords(cubit);
      await cubit.import();
      expect(
        cubit.state.failure,
        isA<ImportMnemonicSourceNotConfirmedFailure>(),
      );
      verifyZeroInteractions(importWallet);
      verifyZeroInteractions(checkWalletStatus);
      await cubit.close();
    });
    test(
      'valid words never contact Electrum before source confirmation',
      () async {
        when(
          () => checkDuplicate.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            passphrase: any(named: 'passphrase'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        final publicFixture = bip39.Mnemonic(
          List.filled(16, 0),
          bip39.Language.english,
        );
        registerFallbackValue(publicFixture);
        registerFallbackValue(ScriptType.bip84);
        final cubit = buildCubit();
        await cubit.updateMnemonic((
          label: 'Public BIP39 vector',
          passphrase: '',
          words: publicFixture.words,
          language: bip39.Language.english,
        ));
        verifyNever(
          () => checkWalletStatus(
            mnemonic: any(named: 'mnemonic'),
            scriptType: any(named: 'scriptType'),
          ),
        );
        await cubit.close();
      },
    );
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
