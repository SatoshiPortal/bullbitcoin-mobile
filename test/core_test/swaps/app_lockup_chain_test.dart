import 'package:bb_mobile/features/swap/data/swaps_runtime_bindings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart' as swaps;
import 'package:sync/sync.dart';

/// Answers every run with [answer] without contacting a server, recording the
/// network it was asked for.
final class _Connections implements WalletConnectionPort {
  Object answer;
  final networks = <Network>[];

  _Connections(this.answer);

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    networks.add(network);
    final answer = this.answer;
    return answer is SyncFailure ? Err(answer) : Ok(answer as T);
  }
}

void main() {
  group('isKnown', () {
    test(
      'asks the Liquid servers of the swap network for a Liquid lockup',
      () async {
        final connections = _Connections(true);

        final known = await AppLockupChain(connections).isKnown(
          txid: 'ab' * 32,
          signedTx: 'pset',
          isLiquid: true,
          environment: NetworkEnv.testnet,
        );

        expect(known, isTrue);
        expect(connections.networks, [LiquidNetwork.testnet]);
      },
    );

    test('asks the Bitcoin servers for a Bitcoin lockup', () async {
      final connections = _Connections(false);

      final known = await AppLockupChain(connections).isKnown(
        txid: 'ab' * 32,
        signedTx: 'psbt',
        isLiquid: false,
        environment: NetworkEnv.mainnet,
      );

      expect(known, isFalse);
      expect(connections.networks, [BitcoinNetwork.mainnet]);
    });

    test('a failed lookup throws instead of reading as absent', () async {
      final connections = _Connections(const SyncConnectionFailure());

      expect(
        AppLockupChain(connections).isKnown(
          txid: 'ab' * 32,
          signedTx: 'pset',
          isLiquid: true,
          environment: NetworkEnv.mainnet,
        ),
        throwsA(isA<swaps.SwapsException>()),
      );
    });
  });

  group('broadcast', () {
    Future<swaps.LockupBroadcast> broadcastLiquid(Object answer) =>
        AppLockupChain(_Connections(answer)).broadcast(
          signedTx: 'pset',
          isLiquid: true,
          environment: NetworkEnv.mainnet,
        );

    test('an accepted lockup carries the txid', () async {
      final outcome = await broadcastLiquid('ab' * 32);

      expect(
        outcome,
        isA<swaps.LockupAccepted>().having((o) => o.txid, 'txid', 'ab' * 32),
      );
    });

    test('a rejection is rejected', () async {
      expect(
        await broadcastLiquid(const SyncBroadcastRejectedFailure()),
        isA<swaps.LockupRejected>(),
      );
    });

    test('a lockup already in the chain is reported as such', () async {
      expect(
        await broadcastLiquid(const SyncAlreadyInChainFailure()),
        isA<swaps.LockupAlreadyInChain>(),
      );
    });

    for (final failure in const <SyncFailure>[
      SyncConnectionFailure(),
      SyncOutcomeUnknownFailure(),
      SyncUnauthorizedNetworkFailure(),
    ]) {
      test('${failure.runtimeType} leaves the outcome unknown', () async {
        expect(
          await broadcastLiquid(failure),
          isA<swaps.LockupOutcomeUnknown>(),
        );
      });
    }
  });
}
