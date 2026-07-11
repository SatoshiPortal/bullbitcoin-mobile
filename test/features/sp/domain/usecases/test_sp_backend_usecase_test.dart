import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TestSpBackendUsecase', () {
    test('blindbit returns null on success', () async {
      final usecase = TestSpBackendUsecase(
        testBlindbit: ({required String url}) async => 42,
        testElectrum: ({required String url}) async {},
      );
      expect(await usecase.test(BackendKind.blindbit, 'http://ok'), isNull);
    });

    test('blindbit returns the error message on failure', () async {
      final usecase = TestSpBackendUsecase(
        testBlindbit: ({required String url}) async => throw Exception('boom'),
        testElectrum: ({required String url}) async {},
      );
      final err = await usecase.test(BackendKind.blindbit, 'http://bad');
      expect(err, isA<SpBackendUnreachable>());
      expect((err! as SpBackendUnreachable).logMessage, contains('boom'));
    });

    test('electrum returns null on success', () async {
      final usecase = TestSpBackendUsecase(
        testBlindbit: ({required String url}) async => 0,
        testElectrum: ({required String url}) async {},
      );
      expect(await usecase.test(BackendKind.electrum, 'tcp://ok:1'), isNull);
    });

    test('electrum returns the error message on failure', () async {
      final usecase = TestSpBackendUsecase(
        testBlindbit: ({required String url}) async => 0,
        testElectrum: ({required String url}) async =>
            throw Exception('no route'),
      );
      final err = await usecase.test(BackendKind.electrum, 'tcp://bad:1');
      expect(err, isA<SpBackendUnreachable>());
      expect((err! as SpBackendUnreachable).logMessage, contains('no route'));
    });
  });
}
