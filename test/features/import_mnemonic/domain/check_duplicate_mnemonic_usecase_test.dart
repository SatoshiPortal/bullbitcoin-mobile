import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSeedRepository extends Mock implements SeedRepository {}

void main() {
  late MockSeedRepository seedRepository;
  late CheckDuplicateMnemonicUsecase usecase;

  const words = ['abandon', 'abandon', 'abandon', 'abandon', 'abandon',
    'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about'];

  setUp(() {
    seedRepository = MockSeedRepository();
    usecase = CheckDuplicateMnemonicUsecase(seedRepository: seedRepository);
  });

  group('CheckDuplicateMnemonicUsecase', () {
    test('returns Ok when mnemonic does not exist', () async {
      when(() => seedRepository.fingerprintFor(
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      )).thenReturn('fp1');
      when(() => seedRepository.exists('fp1')).thenAnswer((_) async => false);

      final result = await usecase.execute(mnemonicWords: words);

      expect(result, isA<Ok<void, ImportMnemonicFailure>>());
    });

    test(
      'returns Err(ImportMnemonicDuplicateFailure) when mnemonic already exists — no raw leak',
      () async {
        when(() => seedRepository.fingerprintFor(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        )).thenReturn('fp1');
        when(() => seedRepository.exists('fp1')).thenAnswer((_) async => true);

        final result = await usecase.execute(mnemonicWords: words);

        expect(result, isA<Err<void, ImportMnemonicFailure>>());
        expect(
          (result as Err).failure,
          isA<ImportMnemonicDuplicateFailure>(),
        );
      },
    );

    test(
      'returns Err(ImportMnemonicUnexpectedFailure) on exception — raw message in logMessage only',
      () async {
        when(() => seedRepository.fingerprintFor(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        )).thenReturn('fp1');
        when(() => seedRepository.exists('fp1'))
            .thenThrow(Exception('db error'));

        final result = await usecase.execute(mnemonicWords: words);

        expect(result, isA<Err<void, ImportMnemonicFailure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<ImportMnemonicUnexpectedFailure>());
        expect(
          (failure as ImportMnemonicUnexpectedFailure).logMessage,
          contains('db error'),
        );
      },
    );
  });
}
