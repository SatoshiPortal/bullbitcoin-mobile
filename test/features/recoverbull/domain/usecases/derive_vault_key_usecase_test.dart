import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/recoverbull_repository_impl.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/pick_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart'
    as core;
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/derive_vault_key_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Picker extends Mock implements PickVaultUsecase {}

class _Seeds extends Mock implements SeedRepository {}

class _Remote extends Mock implements RecoverBullRemoteDatasource {}

class _Settings extends Mock implements RecoverbullSettingsDatasource {}

void main() {
  // Historical vectors retained from 52dca6e53. A legacy unhardened index
  // derives a different key; never normalize its final apostrophe.
  const expectedKey =
      '8f2c4b36f3a0b36058481ea6e2d740ae9b27d46986e24d92cc288bcacbab58d0';
  const legacyKey =
      '151a5a41f5eac5d49e67e0fad0bddd3beebe0f0e4b7739435997506cf12d9fce';
  final words = [...List.filled(11, 'zoo'), 'wrong'];
  final mnemonic = Mnemonic.fromWords(words: words);
  final seed =
      Seed.mnemonic(
            mnemonicWords: words,
            bytes: Uint8List.fromList(mnemonic.seed),
            masterFingerprint: 'fixture',
          )
          as MnemonicSeed;
  late _Picker picker;
  late _Seeds seeds;
  late _Remote remote;
  late _Settings settings;
  late RecoverBullRepositoryImpl repository;
  late DeriveVaultKeyUsecase usecase;

  setUp(() {
    picker = _Picker();
    seeds = _Seeds();
    remote = _Remote();
    settings = _Settings();
    repository = RecoverBullRepositoryImpl(
      remoteDatasource: remote,
      recoverbullSettingsDatasource: settings,
    );
    usecase = DeriveVaultKeyUsecase(
      picker,
      GetAllSeedsUsecase(seedRepository: seeds),
      repository,
    );
    when(() => seeds.getAllMnemonicSeeds()).thenAnswer((_) async => Ok([seed]));
  });

  Future<Result<String, RecoverBullFailure>> derive(EncryptedVault vault) {
    when(() => picker.execute()).thenAnswer((_) async => Ok(vault));
    return usecase.execute();
  }

  for (final failure in [
    const core.InvalidVaultFileFailure(),
    const core.RecoverBullUnexpectedCoreFailure('private picker error'),
  ]) {
    test(
      'maps picker failure without reading seeds or contacting the server: ${failure.runtimeType}',
      () async {
        when(() => picker.execute()).thenAnswer((_) async => Err(failure));
        final result = await usecase.execute();
        final mapped = (result as Err<String, RecoverBullFailure>).failure;
        expect(
          mapped,
          failure is core.InvalidVaultFileFailure
              ? isA<InvalidVaultFileFormatFailure>()
              : isA<SelectVaultFailure>(),
        );
        expect(mapped.logMessage, isNull);
        verifyZeroInteractions(seeds);
        verifyZeroInteractions(remote);
        verifyZeroInteractions(settings);
      },
    );
  }

  EncryptedVault backup({
    String? path = "1608'/0'/586053381'",
    String? payload,
    String key = expectedKey,
  }) {
    final created = repository.createVault(
      vaultKey: key,
      plaintext: payload ?? jsonEncode({'mnemonic': words}),
      derivationPath: path ?? 'unused',
    );
    final vault =
        (created as Ok<EncryptedVault, core.RecoverBullCoreFailure>).value;
    if (path != null) return vault;
    final json = jsonDecode(vault.toFile()) as Map<String, dynamic>;
    json.remove('path');
    return EncryptedVault(file: jsonEncode(json));
  }

  for (final (path, key) in [
    ("1608'/0'/586053381'", expectedKey),
    ("m/1608'/0'/586053381'", expectedKey),
    ("1608'/0'/586053381", legacyKey),
    ("m/1608'/0'/586053381", legacyKey),
  ]) {
    test(
      'derives the recorded historical path $path without any server',
      () async {
        final result = await derive(backup(path: path, key: key));
        expect((result as Ok<String, RecoverBullFailure>).value, key);
        verifyZeroInteractions(remote);
        verifyZeroInteractions(settings);
        verify(() => seeds.getAllMnemonicSeeds()).called(1);
        verifyNoMoreInteractions(seeds);
      },
    );
  }

  for (final path in [
    null,
    '',
    "1608'/1'/586053381'",
    "39'/0'/586053381'",
    "1608'/0'/2147483648'",
    "1608'/0'/-1'",
    "1608'/0'/1'/2'",
    "1608/0/1",
    "1608'/0'/1'\n",
  ]) {
    test(
      'rejects missing/unsupported path before reading any seed: $path',
      () async {
        final result = await derive(backup(path: path));
        expect(
          (result as Err<String, RecoverBullFailure>).failure,
          isA<VaultKeyPathUnavailableFailure>(),
        );
        verifyZeroInteractions(seeds);
        verifyZeroInteractions(remote);
      },
    );
  }

  test(
    'does not guess a new index for a valid but wrong recorded path',
    () async {
      final result = await derive(backup(path: "1608'/0'/1'"));
      expect(
        (result as Err<String, RecoverBullFailure>).failure,
        isA<VaultLocalKeyMismatchFailure>(),
      );
      verifyZeroInteractions(remote);
    },
  );

  test(
    'finds a matching seed even if it is not the first/current wallet',
    () async {
      final other =
          Seed.mnemonic(
                mnemonicWords: words,
                bytes: Uint8List(64),
                masterFingerprint: 'other',
              )
              as MnemonicSeed;
      when(
        () => seeds.getAllMnemonicSeeds(),
      ).thenAnswer((_) async => Ok([other, seed]));
      final result = await derive(backup());
      expect((result as Ok<String, RecoverBullFailure>).value, expectedKey);
    },
  );

  test(
    'does not accept another kind of encrypted RecoverBull payload',
    () async {
      final result = await derive(backup(payload: '{"metadata": {}}'));
      expect(
        (result as Err<String, RecoverBullFailure>).failure,
        isA<VaultLocalKeyMismatchFailure>(),
      );
    },
  );

  test('reports missing local seed separately from wrong seed/file', () async {
    when(
      () => seeds.getAllMnemonicSeeds(),
    ).thenAnswer((_) async => const Ok([]));
    final result = await derive(backup());
    expect(
      (result as Err<String, RecoverBullFailure>).failure,
      isA<VaultSeedUnavailableFailure>(),
    );
  });

  test('never forwards a seed-store error containing private data', () async {
    when(
      () => seeds.getAllMnemonicSeeds(),
    ).thenAnswer((_) async => Err(SeedFetchFailure(words.join(' '))));
    final result = await derive(backup());
    final failure = (result as Err<String, RecoverBullFailure>).failure;
    expect(failure, isA<VaultSeedUnavailableFailure>());
    expect(failure.logMessage, isNull);
  });
}
