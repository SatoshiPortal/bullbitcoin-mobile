import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/get_old_seeds_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/legacy_seed_view/domain/get_legacy_seeds_usecase.dart';
import 'package:bb_mobile/features/legacy_seed_view/domain/legacy_seed_view_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetOldSeedsUsecase extends Mock implements GetOldSeedsUsecase {}

OldSeed _seed(String mnemonic, List<OldPassphrase> passphrases) => OldSeed(
  mnemonic: mnemonic,
  network: OldBBNetwork.Mainnet,
  passphrases: passphrases,
);

void main() {
  late _MockGetOldSeedsUsecase getOldSeedsUsecase;
  late GetLegacySeedsUsecase usecase;

  setUp(() {
    getOldSeedsUsecase = _MockGetOldSeedsUsecase();
    usecase = GetLegacySeedsUsecase(getOldSeedsUsecase: getOldSeedsUsecase);
  });

  group('GetLegacySeedsUsecase', () {
    test(
      'returns LegacySeedViewFetchFailure when the keychain is locked',
      () async {
        when(
          () => getOldSeedsUsecase.execute(),
        ).thenThrow(const KeychainLockedException());

        switch (await usecase.execute()) {
          case Err(:final failure):
            expect(failure, isA<LegacySeedViewFetchFailure>());
            expect(failure.logMessage, isNull);
          case Ok():
            fail('expected a failure');
        }
      },
    );

    test(
      'returns sanitized unexpected failure when the core usecase throws',
      () async {
        when(
          () => getOldSeedsUsecase.execute(),
        ).thenThrow(Exception('raw internal keychain error'));

        switch (await usecase.execute()) {
          case Err(:final failure):
            expect(failure, isA<LegacySeedViewUnexpectedFailure>());
            // Secret-bearing exception text is neither retained nor exposed to UI.
            expect(failure.logMessage, isNull);
          case Ok():
            fail('expected a failure');
        }
      },
    );

    test('returns Ok and dedupes seeds sharing a mnemonic', () async {
      when(() => getOldSeedsUsecase.execute()).thenAnswer(
        (_) async => [
          _seed('alpha', const [OldPassphrase(sourceFingerprint: 'fp1')]),
          _seed('alpha', const [OldPassphrase(sourceFingerprint: 'fp2')]),
          _seed('beta', const []),
        ],
      );

      switch (await usecase.execute()) {
        case Ok(:final value):
          expect(value.length, 2);
          final alpha = value.firstWhere((s) => s.mnemonic == 'alpha');
          expect(alpha.passphrases.length, 2);
        case Err(:final failure):
          fail('expected success, received $failure');
      }
    });
  });
}
