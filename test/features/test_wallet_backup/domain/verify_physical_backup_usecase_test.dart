import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/verify_physical_backup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedRepository extends Mock implements SeedRepository {}

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

void main() {
  late _MockSeedRepository seedRepository;
  late VerifyPhysicalBackupUsecase usecase;

  setUp(() {
    seedRepository = _MockSeedRepository();
    usecase = VerifyPhysicalBackupUsecase(seedRepository: seedRepository);
  });

  group('VerifyPhysicalBackupUsecase', () {
    test('returns true when the words match the stored seed', () async {
      when(() => seedRepository.get(_fingerprint)).thenAnswer(
        (_) async => MnemonicSeed(
          mnemonicWords: _mnemonicWords,
          bytes: Uint8List.fromList([1, 2, 3]),
          masterFingerprint: _fingerprint,
        ),
      );

      final result = await usecase.execute(
        fingerprint: _fingerprint,
        mnemonic: _mnemonicWords,
      );

      expect((result as Ok<bool, TestWalletBackupFailure>).value, isTrue);
    });

    test('returns false when the word order differs', () async {
      when(() => seedRepository.get(_fingerprint)).thenAnswer(
        (_) async => MnemonicSeed(
          mnemonicWords: _mnemonicWords,
          bytes: Uint8List.fromList([1, 2, 3]),
          masterFingerprint: _fingerprint,
        ),
      );

      final shuffled = [..._mnemonicWords]..swap(0, 1);
      final result = await usecase.execute(
        fingerprint: _fingerprint,
        mnemonic: shuffled,
      );

      expect((result as Ok<bool, TestWalletBackupFailure>).value, isFalse);
    });

    test('returns false when the word count differs', () async {
      when(() => seedRepository.get(_fingerprint)).thenAnswer(
        (_) async => MnemonicSeed(
          mnemonicWords: _mnemonicWords,
          bytes: Uint8List.fromList([1, 2, 3]),
          masterFingerprint: _fingerprint,
        ),
      );

      final result = await usecase.execute(
        fingerprint: _fingerprint,
        mnemonic: _mnemonicWords.sublist(0, 11),
      );

      expect((result as Ok<bool, TestWalletBackupFailure>).value, isFalse);
    });

    test(
      'returns a typed failure when the stored seed is not a mnemonic',
      () async {
        when(() => seedRepository.get(_fingerprint)).thenAnswer(
          (_) async => BytesSeed(
            bytes: Uint8List.fromList([1, 2, 3]),
            masterFingerprint: _fingerprint,
          ),
        );

        final result = await usecase.execute(
          fingerprint: _fingerprint,
          mnemonic: _mnemonicWords,
        );

        switch (result) {
          case Ok():
            fail('a non-mnemonic seed must not be reported as a comparison');
          case Err(:final failure):
            expect(failure, isA<TestWalletBackupSeedNotMnemonicFailure>());
            expect(failure.logMessage, isNull);
        }
      },
    );

    test('maps a thrown seed read to a typed failure, keeping the raw reason '
        'in logMessage only — this is the seed path', () async {
      // Shaped like a leak: the reason itself contains mnemonic words.
      when(
        () => seedRepository.get(_fingerprint),
      ).thenThrow(Exception('keychain read failed: legal winner thank year'));

      final result = await usecase.execute(
        fingerprint: _fingerprint,
        mnemonic: _mnemonicWords,
      );

      switch (result) {
        case Ok():
          fail('a thrown seed read must not be reported as a comparison');
        case Err(:final failure):
          expect(failure, isA<TestWalletBackupSeedUnavailableFailure>());
          // Carries NO reason: this failure is stored in bloc state, and the
          // thrown reason came from the seed path. It is logged, not carried.
          expect(failure.logMessage, isNull);
      }
    });
  });
}

extension on List<String> {
  void swap(int a, int b) {
    final tmp = this[a];
    this[a] = this[b];
    this[b] = tmp;
  }
}
