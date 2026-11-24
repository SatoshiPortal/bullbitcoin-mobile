import 'dart:async';

import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/get_sp_scan_server_tip_usecase.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../sp_fakes.dart';

void main() {
  late FakeSpAccountRepository repo;
  late GetSpScanServerTipUsecase usecase;

  setUp(() {
    repo = FakeSpAccountRepository();
    usecase = GetSpScanServerTipUsecase(repository: repo);
  });

  tearDown(() => repo.disposeStreams());

  test('returns the tip the blindbit server reports', () async {
    repo.currentBlockHeightValue = 970180;

    final result = await usecase.execute();

    expect(result, isA<Ok<int, SilentFailure>>());
    expect((result as Ok<int, SilentFailure>).value, 970180);
  });

  test('a failed read is passed through as its typed failure', () async {
    repo.currentBlockHeightShouldFail = true;

    final result = await usecase.execute();

    expect(
      (result as Err<int, SilentFailure>).failure,
      isA<SilentUnexpected>(),
    );
  });

  test('a server that never answers is unreachable, not a hang', () {
    fakeAsync((async) {
      final gate = Completer<Result<int, SilentFailure>>();
      repo.currentBlockHeightOverride = gate.future;
      Result<int, SilentFailure>? result;
      unawaited(usecase.execute().then((value) => result = value));

      async.elapse(const Duration(seconds: 9));
      expect(result, isNull);

      async.elapse(const Duration(seconds: 1));
      expect(
        (result as Err<int, SilentFailure>).failure,
        isA<SilentBackendUnreachable>(),
      );
    });
  });
}
