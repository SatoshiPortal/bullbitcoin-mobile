import 'package:bull_tor/src/domain/tor_repository.dart';
import 'package:bull_tor/src/domain/usecases/set_tor_dormant_usecase.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_tor/tor_adapter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Android protected CBF owner retains Tor until protection ends', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = TorLifecycleController(
      SetTorDormantUsecase(repository),
      const TorLogger(),
      platform: TargetPlatform.android,
    );
    addTearDown(controller.dispose);
    controller.start();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    repository.changes.clear();

    controller.setBackgroundActive(true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(repository.changes, isEmpty);

    controller.setBackgroundActive(false);
    await tester.pump();
    expect(repository.changes, [true]);
  });

  testWidgets('detached always dormants Tor even while protected', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = TorLifecycleController(
      SetTorDormantUsecase(repository),
      const TorLogger(),
      platform: TargetPlatform.android,
    );
    addTearDown(controller.dispose);
    controller.start();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    repository.changes.clear();
    controller.setBackgroundActive(true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump();
    expect(repository.changes, [true]);
  });
  for (final platform in [
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    testWidgets('desktop $platform keeps Tor awake while hidden until exit', (
      tester,
    ) async {
      final repository = _Repository();
      final controller = TorLifecycleController(
        SetTorDormantUsecase(repository),
        const TorLogger(),
        platform: platform,
      );
      addTearDown(controller.dispose);
      controller.start();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      repository.changes.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(repository.changes, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();
      expect(repository.changes, [true]);
    });
  }
}

final class _Repository implements TorRepository {
  final changes = <bool>[];
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
    changes.add(dormant);
  }

  @override
  Stream<TorConnectionState> watch() => const Stream.empty();
}
