import 'dart:async';

import 'package:bb_mobile/features/trezor/application/application_errors.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_base_cubit.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Concrete test subclass exposing `runOperation` publicly so the base
/// behavior can be exercised in isolation. Production subclasses
/// (TrezorImportCubit etc.) inherit the same `runOperation` body.
class _TestCubit extends TrezorOperationBaseCubit<String> {
  Future<void> run(Future<String> Function() op) => runOperation(op);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('detects launch failure when app resumes mid-await without callback '
        '(regression: review #12 Suite-not-installed)', () async {
      final cubit = _TestCubit();
      final completer = Completer<String>();

      // Kick off operation — completer never resolves, simulating
      // the "no callback ever arrives" path.
      unawaited(cubit.run(() => completer.future));
      await pumpEventQueue();
      expect(cubit.state.status, TrezorOperationStatus.waitingForSuite);

      // Simulate the launchUrl handoff: app goes to background.
      cubit.didChangeAppLifecycleState(AppLifecycleState.paused);

      // User comes back to Bull manually (Suite wasn't installed,
      // Chrome showed the download page, user navigated back).
      cubit.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Mid-grace: still waiting.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(cubit.state.status, TrezorOperationStatus.waitingForSuite);

      // Past grace: error emitted with Suite-not-installed message.
      await Future<void>.delayed(const Duration(milliseconds: 2000));
      expect(cubit.state.status, TrezorOperationStatus.error);
      expect(cubit.state.errorMessage, contains("didn't respond"));

      await cubit.close();
    });

    test(
      'cancels grace timer when callback arrives during grace period',
      () async {
        final cubit = _TestCubit();
        final completer = Completer<String>();
        unawaited(cubit.run(() => completer.future));
        await pumpEventQueue();

        cubit.didChangeAppLifecycleState(AppLifecycleState.paused);
        cubit.didChangeAppLifecycleState(AppLifecycleState.resumed);

        // Callback arrives within the grace window.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        completer.complete('result');
        await pumpEventQueue();
        expect(cubit.state.status, TrezorOperationStatus.success);
        expect(cubit.state.result, 'result');

        // Past where grace would have fired — state must stay `success`.
        await Future<void>.delayed(const Duration(milliseconds: 2000));
        expect(cubit.state.status, TrezorOperationStatus.success);

        await cubit.close();
      },
    );

    test(
      'transient inactive (notification panel) does not trigger grace timer',
      () async {
        final cubit = _TestCubit();
        final completer = Completer<String>();
        unawaited(cubit.run(() => completer.future));
        await pumpEventQueue();

        // Notification panel pulldown / control center.
        cubit.didChangeAppLifecycleState(AppLifecycleState.inactive);
        cubit.didChangeAppLifecycleState(AppLifecycleState.resumed);

        // 2.5s later — no error should have fired, _wasBackgrounded was
        // never set true.
        await Future<void>.delayed(const Duration(milliseconds: 2500));
        expect(cubit.state.status, TrezorOperationStatus.waitingForSuite);

        completer.complete('result');
        await pumpEventQueue();
        expect(cubit.state.status, TrezorOperationStatus.success);

        await cubit.close();
      },
    );
  });
}
