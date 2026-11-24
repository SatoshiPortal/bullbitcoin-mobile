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
    final subscription = cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);
    return cubit;
  }

  Future<void> closeCubit() async {
    closed = true;
    await cubit.close();
  }

  test('runs, then reports the completed scan', () async {
    build((walletId) async {
      requested.add(walletId);
      return const Ok(null);
    });

    await cubit.discover('wallet-1');

    expect(requested, ['wallet-1']);
    expect(states, hasLength(2));
    expect(states.first, isA<WalletDiscoveryRunning>());
    expect(states.last, isA<WalletDiscoverySucceeded>());
  });

  test('reports a failed scan with its own failure', () async {
    build((_) async => const Err(WalletDetailsDiscoveryFailure()));

    await cubit.discover('wallet-1');

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
    await pumpEventQueue();
    final second = cubit.discover('wallet-2');
    gate.complete(const Ok(null));
    await first;
    await second;

    expect(requested, ['wallet-1']);
    expect(states.last, isA<WalletDiscoverySucceeded>());
  });

  test('a late scan cannot emit after the cubit is closed', () async {
    final gate = Completer<Result<void, WalletDetailsFailure>>();
    build((_) => gate.future);

    final pending = cubit.discover('wallet-1');
    await pumpEventQueue();
    await cubit.close();
    final emittedBeforeClose = List.of(states);
    gate.complete(const Ok(null));

    await expectLater(pending, completes);
    expect(states, emittedBeforeClose);
    expect(states.last, isA<WalletDiscoveryRunning>());
  });
}
