import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_backend_probe_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProbe implements SpBackendProbePort {
  final Result<void, SpFailure> _result;

  _FakeProbe(this._result);

  @override
  Future<Result<void, SpFailure>> testBackend(
    SpBackendKind kind,
    String url,
  ) async => _result;

  @override
  Future<Result<SpBackendDefaults, SpFailure>> fetchRegtestDefaults() =>
      throw UnimplementedError();
}

void main() {
  group('TestSpBackendUsecase', () {
    test('forwards the probe Ok', () async {
      final usecase = TestSpBackendUsecase(probe: _FakeProbe(const Ok(null)));
      expect(
        await usecase.execute(SpBackendKind.blindbit, 'http://ok'),
        isA<Ok<void, SpFailure>>(),
      );
    });

    test('forwards the probe Err', () async {
      final usecase = TestSpBackendUsecase(
        probe: _FakeProbe(const Err(SpBackendUnreachable('boom'))),
      );
      final result = await usecase.execute(
        SpBackendKind.electrum,
        'tcp://bad:1',
      );
      final failure = (result as Err<void, SpFailure>).failure;
      expect(failure, isA<SpBackendUnreachable>());
      expect(failure.logMessage, contains('boom'));
    });
  });
}
