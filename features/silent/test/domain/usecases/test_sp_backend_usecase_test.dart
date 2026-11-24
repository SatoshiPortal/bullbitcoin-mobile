import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_backend_defaults.dart';
import 'package:silent/src/domain/entities/sp_backend_kind.dart';
import 'package:silent/src/domain/ports/sp_backend_probe_port.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/test_sp_backend_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProbe implements SpBackendProbePort {
  final Result<void, SilentFailure> _result;

  _FakeProbe(this._result);

  @override
  Future<Result<void, SilentFailure>> testBackend(
    SpBackendKind kind,
    String url,
  ) async => _result;

  @override
  Future<Result<SpBackendDefaults, SilentFailure>> fetchRegtestDefaults() =>
      throw UnimplementedError();
}

void main() {
  group('TestSpBackendUsecase', () {
    test('forwards the probe Ok', () async {
      final usecase = TestSpBackendUsecase(probe: _FakeProbe(const Ok(null)));
      expect(
        await usecase.execute(SpBackendKind.blindbit, 'http://ok'),
        isA<Ok<void, SilentFailure>>(),
      );
    });

    test('forwards the probe Err', () async {
      final usecase = TestSpBackendUsecase(
        probe: _FakeProbe(const Err(SilentBackendUnreachable('boom'))),
      );
      final result = await usecase.execute(
        SpBackendKind.electrum,
        'tcp://bad:1',
      );
      final failure = (result as Err<void, SilentFailure>).failure;
      expect(failure, isA<SilentBackendUnreachable>());
      expect(failure.logMessage, contains('boom'));
    });
  });
}
