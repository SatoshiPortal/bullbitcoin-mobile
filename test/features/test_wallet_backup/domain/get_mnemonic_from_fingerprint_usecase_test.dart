import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedRepository extends Mock implements SeedRepository {}

void main() {
  const fingerprint = 'f00dbabe';
  const words = ['abandon', 'ability', 'able'];
  late _MockSeedRepository seedRepository;
  late GetMnemonicFromFingerprintUsecase usecase;

  setUp(() {
    seedRepository = _MockSeedRepository();
    usecase = GetMnemonicFromFingerprintUsecase(seedRepository: seedRepository);
  });

  test('returns recovery words for a mnemonic seed', () async {
    when(() => seedRepository.get(fingerprint)).thenAnswer(
      (_) async => Seed.mnemonic(
        mnemonicWords: words,
        passphrase: 'passphrase',
        bytes: Uint8List(32),
        masterFingerprint: fingerprint,
      ),
    );

    final result = await usecase.execute(fingerprint);

    expect(
      result,
      isA<Ok<(List<String>, String?), TestWalletBackupFailure>>()
          .having((result) => result.value.$1, 'words', words)
          .having((result) => result.value.$2, 'passphrase', 'passphrase'),
    );
  });

  test('maps a non-mnemonic seed to a typed load failure', () async {
    when(() => seedRepository.get(fingerprint)).thenAnswer(
      (_) async =>
          Seed.bytes(bytes: Uint8List(32), masterFingerprint: fingerprint),
    );

    final result = await usecase.execute(fingerprint);

    expect(
      result,
      isA<Err<(List<String>, String?), TestWalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<TestWalletBackupLoadMnemonicFailure>(),
      ),
    );
  });

  test('maps repository exceptions to a typed load failure', () async {
    when(
      () => seedRepository.get(fingerprint),
    ).thenThrow(Exception('sensitive storage detail'));

    final result = await usecase.execute(fingerprint);

    expect(
      result,
      isA<Err<(List<String>, String?), TestWalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<TestWalletBackupLoadMnemonicFailure>(),
      ),
    );
  });
}
