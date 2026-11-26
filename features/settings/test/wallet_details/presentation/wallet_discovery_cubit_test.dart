import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:primitives/primitives.dart';

import 'package:settings/src/wallet_details/domain/discover_wallet_usecase.dart';
import 'package:settings/src/wallet_details/domain/wallet_details_failure.dart';
import 'package:settings/src/wallet_details/presentation/wallet_discovery_cubit.dart';

void main() {
  late List<String> requested;
  late WalletDiscoveryCubit cubit;
  late List<WalletDiscoveryState> states;
  late Completer<void> stateDelivered;
  late bool streamClosed;
  late bool closed;

  setUp(() {
    requested = [];
    closed = false;
  });

  tearDown(() async {
    if (!closed) await cubit.close();
  });

  WalletDiscoveryCubit build(
    Future<Result<void, WalletDetailsFailure>> Function(String walletId)
    discover,
  ) {
    cubit = WalletDiscoveryCubit(DiscoverWalletUsecase(discover));
    states = [];
    streamClosed = false;
    stateDelivered = Completer<void>();
    final subscription = cubit.stream.listen(
      (state) {
        states.add(state);
        final delivered = stateDelivered;
        stateDelivered = Completer<void>();
        delivered.complete();
      },
      onDone: () {
        streamClosed = true;
        if (!stateDelivered.isCompleted) stateDelivered.complete();
      },
    );
    addTearDown(subscription.cancel);
    return cubit;
  }

  Future<void> closeCubit() async {
    closed = true;
    await cubit.close();
  }

  /// Waits until the cubit has delivered [count] states, so an assertion reads
  /// a settled history instead of racing the asynchronous cubit stream.
  Future<void> waitForStates(int count) async {
    while (states.length < count) {
      if (streamClosed) {
        fail('the cubit closed after ${states.length} states, expected $count');
      }
      await stateDelivered.future;
    }
  }

  test('runs, then reports the completed scan', () async {
    build((walletId) async {
      requested.add(walletId);
      return const Ok(null);
    });

    await cubit.discover('wallet-1');
    await waitForStates(2);

    expect(requested, ['wallet-1']);
    expect(states, hasLength(2));
    expect(states.first, isA<WalletDiscoveryRunning>());
    expect(states.last, isA<WalletDiscoverySucceeded>());
  });

  test('reports a failed scan with its own failure', () async {
    build((_) async => const Err(WalletDetailsDiscoveryFailure()));

    await cubit.discover('wallet-1');
    await waitForStates(2);

    expect(
      states.last,
      isA<WalletDiscoveryFailed>().having(
        (state) => state.failure,
        'failure',
        isA<WalletDetailsDiscoveryFailure>(),
      ),
    );
  });

  test('ignores a second scan while one is running', () async {
    final gate = Completer<Result<void, WalletDetailsFailure>>();
    build((walletId) {
      requested.add(walletId);
      return gate.future;
    });

    final first = cubit.discover('wallet-1');
    await waitForStates(1);
    final second = cubit.discover('wallet-2');
    gate.complete(const Ok(null));
    await first;
    await second;
    await waitForStates(2);

    expect(requested, ['wallet-1']);
    expect(states.last, isA<WalletDiscoverySucceeded>());
  });

  test('a late scan cannot emit after the cubit is closed', () async {
    final gate = Completer<Result<void, WalletDetailsFailure>>();
    build((_) => gate.future);

    final pending = cubit.discover('wallet-1');
    await waitForStates(1);
    await closeCubit();
    final emittedBeforeClose = List.of(states);
    gate.complete(const Ok(null));

    await expectLater(pending, completes);
    expect(states, emittedBeforeClose);
    expect(states.last, isA<WalletDiscoveryRunning>());
  });
}
