import 'dart:async';

import 'package:bb_mobile/features/trezor/application/application_errors.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_base_cubit.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Concrete test subclass exposing `runOperation` publicly so the base
/// behavior can be exercised in isolation. Production subclasses
/// (TrezorImportCubit etc.) inherit the same `runOperation` body.
class _TestCubit extends TrezorOperationBaseCubit<String> {
  Future<void> run(Future<String> Function() op) => runOperation(op);
}

void main() {
  group('TrezorOperationBaseCubit close-guards', () {
    test('does not throw when the operation resolves after close', () async {
      final cubit = _TestCubit();
      final completer = Completer<String>();

      // Kick off the operation — it awaits the completer.
      final inflight = cubit.run(() => completer.future);

      // Close the cubit while the operation is mid-await.
      // Simulates the user navigating back from the Trezor screen.
      await cubit.close();

      // Resolve the operation. Without the close-guard, the base
      // cubit would try to emit(success) and throw
      // "Cannot emit new states after calling close()".
      completer.complete('result');

      // runOperation should complete cleanly with no thrown error.
      await expectLater(inflight, completes);
    });

    test('does not throw when the operation errors after close', () async {
      final cubit = _TestCubit();
      final completer = Completer<String>();

      final inflight = cubit.run(() => completer.future);
      await cubit.close();

      completer.completeError(const TrezorApplicationError.userRejected());

      await expectLater(inflight, completes);
    });

    test('emits success normally when not closed', () async {
      final cubit = _TestCubit();
      final states = <TrezorOperationState<String>>[];
      cubit.stream.listen(states.add);

      await cubit.run(() async => 'ok');

      // Cubit emits are delivered to listeners via microtasks. After
      // run() resolves, the cubit has emitted internally but the
      // listener may not have processed every event yet — drain the
      // queue before asserting.
      await pumpEventQueue();

      // launching → waitingForSuite → success
      expect(states, hasLength(3));
      expect(states.last.status, TrezorOperationStatus.success);
      expect(states.last.result, 'ok');

      await cubit.close();
    });
  });
}
