import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/reveal_data_recovery_words_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Seed extends Mock implements GetDefaultSeedUsecase {}

class _Settings extends Mock implements GetSettingsUsecase {}

void main() {
  final seed = Seed.bytes(bytes: Uint8List(64), masterFingerprint: 'aabbccdd');
  late _Seed seeds;
  late _Settings settings;
  late RevealDataRecoveryWordsUsecase usecase;
  setUp(() {
    seeds = _Seed();
    settings = _Settings();
    when(settings.execute).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'USD',
      ),
    );
    when(
      () => seeds.execute(environment: Environment.testnet),
    ).thenAnswer((_) async => seed);
    usecase = RevealDataRecoveryWordsUsecase(settings, seeds);
  });

  test(
    'reveals index-100 words using the current environment and origin',
    () async {
      final result = await usecase.execute(expectedFingerprint: 'AABBCCDD');
      final value =
          (result as Ok<RevealedDataRecoveryWords, BackupSettingsFailure>)
              .value;
      expect(value.words, BackupCredential.deriveWords(seed));
      expect(value.toString(), isNot(contains(value.words)));
      verify(() => seeds.execute(environment: Environment.testnet)).called(1);
    },
  );

  test(
    'a vault without a recorded origin never falls back to device words',
    () async {
      expect(
        await usecase.execute(forVault: true),
        isA<Err<RevealedDataRecoveryWords, BackupSettingsFailure>>(),
      );
      verifyNever(settings.execute);
      verifyNever(() => seeds.execute(environment: any(named: 'environment')));
    },
  );

  test(
    'rejects another seed even if the earlier public origin check passed',
    () async {
      expect(
        await usecase.execute(expectedFingerprint: '11223344'),
        isA<Err<RevealedDataRecoveryWords, BackupSettingsFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<BackupSettingsWordsUnavailableFailure>(),
        ),
      );
    },
  );

  test(
    'global reveal needs no vault origin, but missing or locked seed fails',
    () async {
      expect(
        await usecase.execute(),
        isA<Ok<RevealedDataRecoveryWords, BackupSettingsFailure>>(),
      );
      when(
        () => seeds.execute(environment: Environment.testnet),
      ).thenThrow(Exception('locked'));
      expect(
        await usecase.execute(),
        isA<Err<RevealedDataRecoveryWords, BackupSettingsFailure>>(),
      );
    },
  );

  test(
    'settings failure never reads a seed or exposes a foreign message',
    () async {
      when(settings.execute).thenThrow(Exception('private storage detail'));
      final result = await usecase.execute();
      expect(
        result,
        isA<Err<RevealedDataRecoveryWords, BackupSettingsFailure>>(),
      );
      verifyNever(() => seeds.execute(environment: any(named: 'environment')));
      expect(
        (result as Err).failure.logMessage,
        isNot(contains('private storage detail')),
      );
    },
  );
}
