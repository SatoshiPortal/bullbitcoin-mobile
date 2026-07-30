import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tor/src/domain/tor_repository.dart';
import 'package:tor/src/domain/usecases/set_tor_dormant_usecase.dart';
import 'package:tor/tor.dart';
import 'package:tor/tor_adapter.dart';

void main() {
  testWidgets('sleeps in background and wakes on resume', (tester) async {
    final repository = _FakeTorRepository();
    final controller = TorLifecycleController(
      SetTorDormantUsecase(repository),
      const TorLogger(),
    );
    addTearDown(controller.dispose);
    controller.start();
    await tester.pump();
    repository.dormancyChanges.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(repository.dormancyChanges, [true]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repository.dormancyChanges, [true, false]);
  });
}

final class _FakeTorRepository implements TorRepository {
  final List<bool> dormancyChanges = [];

  @override
  TorConnectionState get current => const TorUninitialized();

  @override
  TorTransportMode get mode => TorTransportMode.automatic;

  @override
  Future<void> close() async {}

  @override
  Future<TorConnectionState> ensureReady() => throw UnimplementedError();

  @override
  Future<TorConnectionState> retry() => throw UnimplementedError();

  @override
  Future<TorSession> openSession() => throw UnimplementedError();

  @override
  Future<TorConnectionState> setMode(TorTransportMode mode) =>
      throw UnimplementedError();

  @override
  Future<void> setDormant(bool dormant) async {
    dormancyChanges.add(dormant);
  }

  @override
  Stream<TorConnectionState> watch() => const Stream.empty();
}
