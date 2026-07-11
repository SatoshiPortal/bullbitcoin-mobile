import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConfigRepository implements SpBackendConfigRepository {
  final Result<void, SpFailure> _result;

  _FakeConfigRepository(this._result);

  @override
  Future<Result<void, SpFailure>> testBackend(SpBackendKind kind, String url) async =>
      _result;

  @override
  Future<void> save(SpBackendConfig config) => throw UnimplementedError();
  @override
  Future<Result<SpBackendConfig?, SpFailure>> fetch() => throw UnimplementedError();
  @override
  Future<void> delete() => throw UnimplementedError();
  @override
  SpBackendDefaults fetchRegtestDefaults() => throw UnimplementedError();
}

void main() {
  group('TestSpBackendUsecase', () {
    test('forwards an Ok as null', () async {
      final usecase = TestSpBackendUsecase(
        configRepository: _FakeConfigRepository(const Ok(null)),
      );
      expect(await usecase.execute(SpBackendKind.blindbit, 'http://ok'), isNull);
    });

    test('forwards an Err as the failure', () async {
      final usecase = TestSpBackendUsecase(
        configRepository: _FakeConfigRepository(
          const Err(SpBackendUnreachable('boom')),
        ),
      );
      final err = await usecase.execute(SpBackendKind.electrum, 'tcp://bad:1');
      expect(err, isA<SpBackendUnreachable>());
      expect((err! as SpBackendUnreachable).logMessage, contains('boom'));
    });
  });
}
