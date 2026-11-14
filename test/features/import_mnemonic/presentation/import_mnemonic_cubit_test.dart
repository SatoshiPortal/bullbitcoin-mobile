import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Err, Ok, Result;
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'dart:async';

import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/scan_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart'
    show ScriptType, Wallet;

class MockWallet extends Mock implements Wallet {}

class _MockMetadata extends Mock implements WalletMetadataDatasource {}

class _MockSettings extends Mock implements SettingsRepository {}

class MockImportWalletUsecase extends Mock implements ImportWalletUsecase {}

class MockScanMnemonicUsecase extends Mock implements ScanMnemonicUsecase {}

typedef _Scan = Future<Result<MnemonicScan, ImportMnemonicScanFailure>>;

class MockCheckDuplicateMnemonicUsecase extends Mock
    implements CheckDuplicateMnemonicUsecase {}

class MockMetadata extends Mock implements WalletMetadataDatasource {}

class MockSettings extends Mock implements SettingsRepository {}

void main() {
  late MockImportWalletUsecase importWallet;
  late MockScanMnemonicUsecase scanMnemonic;
  late MockCheckDuplicateMnemonicUsecase checkDuplicate;

  ImportMnemonicCubit buildCubit() => ImportMnemonicCubit(
    importWalletUsecase: importWallet,
    scanMnemonicUsecase: scanMnemonic,
    checkDuplicateMnemonicUsecase: checkDuplicate,
  );

  setUp(() {
    importWallet = MockImportWalletUsecase();
    scanMnemonic = MockScanMnemonicUsecase();
    checkDuplicate = MockCheckDuplicateMnemonicUsecase();
    when(
      () => scanMnemonic.execute(
        words: any(named: 'words'),
        language: any(named: 'language'),
        passphrase: any(named: 'passphrase'),
        scriptTypes: any(named: 'scriptTypes'),
      ),
    ).thenReturn({});
  });

  setUpAll(() {
    registerFallbackValue(bip39.Language.english);
    registerFallbackValue(<ScriptType>{});
  });

  test('accepts a Japanese vector before scanning', () async {
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    final metadata = _MockMetadata();
    when(metadata.fetchAll).thenAnswer((_) async => []);
    final settings = _MockSettings();
    when(settings.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    final cubit = ImportMnemonicCubit(
      importWalletUsecase: importWallet,
      scanMnemonicUsecase: scanMnemonic,
      checkDuplicateMnemonicUsecase: CheckDuplicateMnemonicUsecase(
        metadata: metadata,
        settings: settings,
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
          () => scanMnemonic.execute(
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

    setUp(() {
      when(
        () => checkDuplicate.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => const Ok(null));
    });

    void scans(Map<ScriptType, _Scan> Function(Set<ScriptType>) answer) =>
        when(
          () => scanMnemonic.execute(
            words: any(named: 'words'),
            language: any(named: 'language'),
            passphrase: any(named: 'passphrase'),
            scriptTypes: any(named: 'scriptTypes'),
          ),
        ).thenAnswer(
          (invocation) => answer(
            invocation.namedArguments[#scriptTypes] as Set<ScriptType>,
          ),
        );

    test(
      'requests the three script types in one call and emits each scan',
      () async {
        final bip49 =
            Completer<Result<MnemonicScan, ImportMnemonicScanFailure>>();
        final bip44 =
            Completer<Result<MnemonicScan, ImportMnemonicScanFailure>>();
        scans(
          (_) => {
            ScriptType.bip84: Future.value(
              Ok((
                satoshis: BigInt.from(status.satoshis),
                transactions: status.transactions,
              )),
            ),
            ScriptType.bip49: bip49.future,
            ScriptType.bip44: bip44.future,
          },
        );
        final cubit = buildCubit();

        await cubit.updateMnemonic(mnemonic);
        await pumpEventQueue();

        // The pending bip49 and bip44 scans do not hold back bip84.
        expect(
          cubit.state.bip84Scan,
          ScriptTypeScan.found(
            satoshis: BigInt.from(status.satoshis),
            transactions: status.transactions,
          ),
        );
        expect(cubit.state.bip49Scan, const ScriptTypeScan.loading());
        expect(cubit.state.bip44Scan, const ScriptTypeScan.loading());

        bip49.complete(Ok((satoshis: BigInt.zero, transactions: 0)));
        await pumpEventQueue();
        expect(cubit.state.bip49Scan, const ScriptTypeScan.empty());

        verify(
          () => scanMnemonic.execute(
            words: mnemonic.words,
            language: bip39.Language.english,
            passphrase: 'TREZOR',
            scriptTypes: {ScriptType.bip84, ScriptType.bip49, ScriptType.bip44},
          ),
        ).called(1);

        await cubit.close();
      },
    );

    test(
      'a failed scan is a typed failure, not an empty or pending wallet',
      () async {
        scans(
          (types) => {
            for (final type in types)
              type: type == ScriptType.bip44
                  ? Future.value(
                      const Err(ImportMnemonicScanServerUnavailableFailure()),
                    )
                  : Future.value(Ok((satoshis: BigInt.zero, transactions: 0))),
          },
        );
        final cubit = buildCubit();

        await cubit.updateMnemonic(mnemonic);
        await pumpEventQueue();

        expect(
          cubit.state.bip44Scan,
          const ScriptTypeScan.failed(
            ImportMnemonicScanServerUnavailableFailure(),
          ),
        );
        expect(cubit.state.bip84Scan, const ScriptTypeScan.empty());
        // The scan is informational: no blocking failure, the import stays possible.
        expect(cubit.state.failure, isNull);
        expect(cubit.state.mnemonic, mnemonic);

        await cubit.close();
      },
    );

    test('retry scans the failed script type alone', () async {
      var attempts = 0;
      scans(
        (types) => {
          for (final type in types)
            type: type == ScriptType.bip49 && attempts++ == 0
                ? Future.value(const Err(ImportMnemonicScanTimeoutFailure()))
                : Future.value(
                    Ok((satoshis: BigInt.from(21), transactions: 1)),
                  ),
        },
      );
      final cubit = buildCubit();
      await cubit.updateMnemonic(mnemonic);
      await pumpEventQueue();
      expect(
        cubit.state.bip49Scan,
        const ScriptTypeScan.failed(ImportMnemonicScanTimeoutFailure()),
      );

      final retry = cubit.retryScan(ScriptType.bip49);
      expect(cubit.state.bip49Scan, const ScriptTypeScan.loading());
      await retry;

      expect(
        cubit.state.bip49Scan,
        ScriptTypeScan.found(satoshis: BigInt.from(21), transactions: 1),
      );
      verify(
        () => scanMnemonic.execute(
          words: mnemonic.words,
          language: bip39.Language.english,
          passphrase: 'TREZOR',
          scriptTypes: {ScriptType.bip49},
        ),
      ).called(1);

      await cubit.close();
    });

    test('retry ignores a script type that did not fail', () async {
      scans(
        (types) => {
          for (final type in types)
            type: Future.value(Ok((satoshis: BigInt.zero, transactions: 0))),
        },
      );
      final cubit = buildCubit();
      await cubit.updateMnemonic(mnemonic);
      await pumpEventQueue();

      await cubit.retryScan(ScriptType.bip84);

      verify(
        () => scanMnemonic.execute(
          words: any(named: 'words'),
          language: any(named: 'language'),
          passphrase: any(named: 'passphrase'),
          scriptTypes: any(named: 'scriptTypes'),
        ),
      ).called(1);

      await cubit.close();
    });

    test('a scan of a replaced mnemonic is dropped', () async {
      final pending =
          Completer<Result<MnemonicScan, ImportMnemonicScanFailure>>();
      scans((types) => {for (final type in types) type: pending.future});
      final cubit = buildCubit();
      await cubit.updateMnemonic(mnemonic);
      cubit.reset();

      pending.complete(const Err(ImportMnemonicScanTimeoutFailure()));
      await pumpEventQueue();

      expect(cubit.state.bip84Scan, const ScriptTypeScan.loading());

      await cubit.close();
    });

    test('the state description names no word nor passphrase', () async {
      scans(
        (types) => {
          for (final type in types)
            type: Future.value(
              const Err(ImportMnemonicScanUnexpectedFailure('StateError')),
            ),
        },
      );
      final cubit = buildCubit();
      await cubit.updateMnemonic(mnemonic);
      await pumpEventQueue();

      final description = cubit.state.toString();
      expect(description, contains('ImportMnemonicScanUnexpectedFailure'));
      for (final secret in [...mnemonic.words, mnemonic.passphrase]) {
        expect(description, isNot(contains(secret)));
      }
      expect(description, isNot(contains('StateError')));

      await cubit.close();
    });
  });
}
