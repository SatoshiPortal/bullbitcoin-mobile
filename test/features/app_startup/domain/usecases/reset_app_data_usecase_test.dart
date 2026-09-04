import 'dart:io';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPinCodeRepository extends Mock implements PinCodeRepository {}

void main() {
  late _MockPinCodeRepository pinCodeRepository;

  setUp(() {
    pinCodeRepository = _MockPinCodeRepository();
    when(
      () => pinCodeRepository.deletePinCode(),
    ).thenAnswer((_) async => const Ok(null));
  });

  test(
    'clears the residual PIN without resetting the composed RecoverBull DB',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recoverbull-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final lifecycle = RecoverBullLifecycle();
      addTearDown(lifecycle.dispose);
      final database = await lifecycle.openDatabase(
        '${directory.path}/recoverbull.sqlite',
      );
      final usecase = ResetAppDataUsecase(pinCodeRepository: pinCodeRepository);

      await usecase.execute();

      verify(() => pinCodeRepository.deletePinCode()).called(1);
      expect(await database.customSelect('SELECT 1').get(), isNotEmpty);
    },
  );
}
