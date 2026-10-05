import 'dart:async';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/psbt_flow/domain/generate_psbt_qr_parts_usecase.dart';
import 'package:bb_mobile/features/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:bb_mobile/features/psbt_flow/show_animated_qr/show_animated_qr_cubit.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands back a canned result, or hangs on [pending] to model an encode that
/// is still running when the screen is popped.
class _FakeGeneratePsbtQrPartsUsecase implements GeneratePsbtQrPartsUsecase {
  Result<List<String>, PsbtFlowFailure> result;
  Completer<Result<List<String>, PsbtFlowFailure>>? pending;
  int calls = 0;

  _FakeGeneratePsbtQrPartsUsecase(this.result);

  @override
  Future<Result<List<String>, PsbtFlowFailure>> execute({
    required String psbt,
    required QrType qrType,
    required int fragmentLength,
  }) {
    calls += 1;
    final inFlight = pending;
    return inFlight != null ? inFlight.future : Future.value(result);
  }
}

ShowAnimatedQrCubit _cubitWith(
  _FakeGeneratePsbtQrPartsUsecase usecase, {
  QrType qrType = QrType.urqr,
}) => ShowAnimatedQrCubit(
  generatePsbtQrPartsUsecase: usecase,
  psbt: 'cHNidP8BAAoAAAAAAAAAAAAA',
  qrType: qrType,
);

void main() {
  group('ShowAnimatedQrCubit', () {
    test('shows the encoded parts and cycles through them', () {
      fakeAsync((async) {
        final cubit = _cubitWith(
          _FakeGeneratePsbtQrPartsUsecase(const Ok(['part-1', 'part-2'])),
        );
        async.flushMicrotasks();

        expect(cubit.state.isLoading, isFalse);
        expect(cubit.state.failure, isNull);
        expect(cubit.state.parts, ['part-1', 'part-2']);
        expect(cubit.state.currentIndex, 0);

        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.currentIndex, 1);

        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('surfaces the typed failure and shows no parts', () async {
      final cubit = _cubitWith(
        _FakeGeneratePsbtQrPartsUsecase(
          const Err(PsbtFlowInvalidPsbtFailure()),
        ),
      );

      await cubit.stream.firstWhere((state) => !state.isLoading);

      expect(cubit.state.failure, isA<PsbtFlowInvalidPsbtFailure>());
      expect(cubit.state.parts, isEmpty);
      await cubit.close();
    });

    test('stops cycling stale parts once a regeneration fails', () {
      fakeAsync((async) {
        final usecase = _FakeGeneratePsbtQrPartsUsecase(
          const Ok(['part-1', 'part-2']),
        );
        final cubit = _cubitWith(usecase);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.currentIndex, 1);

        usecase.result = const Err(PsbtFlowQrEncodingFailure());
        cubit.updateFragmentLength(120);
        async.flushMicrotasks();

        expect(cubit.state.failure, isA<PsbtFlowQrEncodingFailure>());
        final frozenIndex = cubit.state.currentIndex;

        // A timer left over from the successful run would keep advancing the
        // index behind the error message.
        async.elapse(const Duration(seconds: 5));
        expect(cubit.state.currentIndex, frozenIndex);

        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('clears a previous failure while regenerating', () async {
      final usecase = _FakeGeneratePsbtQrPartsUsecase(
        const Err(PsbtFlowQrEncodingFailure()),
      );
      final cubit = _cubitWith(usecase);
      await cubit.stream.firstWhere((state) => state.failure != null);

      usecase.result = const Ok(['part-1']);
      final cleared = cubit.stream.firstWhere((state) => state.isLoading);
      cubit.updateFragmentLength(120);

      expect((await cleared).failure, isNull);
      await cubit.close();
    });

    test('does not emit when the screen is popped mid-encode', () async {
      final usecase = _FakeGeneratePsbtQrPartsUsecase(const Ok(['part-1']))
        ..pending = Completer<Result<List<String>, PsbtFlowFailure>>();
      final cubit = _cubitWith(usecase);

      await cubit.close();
      // Emitting on a closed cubit throws a StateError, which would surface as
      // an unhandled async error and fail this test.
      usecase.pending!.complete(const Ok(['part-1']));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.parts, isEmpty);
    });
  });
}
