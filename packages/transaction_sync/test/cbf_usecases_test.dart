import 'dart:typed_data';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/src/domain/repositories/wallet_transaction_repository.dart';

final class _Repository implements WalletTransactionRepository {
  BroadcastCbfTransactionRequest? request;
  @override
  Future<Result<String, WalletTransactionSyncFailure>> broadcastCbf(
    BroadcastCbfTransactionRequest request,
  ) async {
    this.request = request;
    return const Err(CbfBroadcastNotRelayedFailure());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Progress implements BitcoinSyncProgressRepository {
  WalletNetworkKey? requested;
  @override
  Stream<BitcoinSyncProgress> watchBitcoinSyncProgress(WalletNetworkKey key) {
    requested = key;
    return Stream.value(
      BitcoinSyncProgress(key: key, phase: BitcoinSyncPhase.findingPeers),
    );
  }
}

void main() {
  const key = WalletNetworkKey('public', 'bitcoin', 'mainnet');
  test('broadcast usecase preserves typed result and exact request', () async {
    final repository = _Repository();
    final bytes = Uint8List.fromList([1, 2]);
    final request = BroadcastCbfTransactionRequest(
      registration: const WalletSourceRegistration(
        key: key,
        sourceKind: 'bdk_electrum',
        configurationFingerprint: 'public',
      ),
      transactionBytes: bytes,
    );
    bytes[0] = 3;
    final result = await BroadcastCbfTransactionUsecase(
      repository,
    ).execute(request);
    expect(result, isA<Err<String, WalletTransactionSyncFailure>>());
    expect(repository.request, same(request));
    expect(request.transactionBytes[0], 1);
  });
  test(
    'progress usecase watches one wallet without initiating network work',
    () async {
      final repository = _Progress();
      final event = await WatchBitcoinSyncProgressUsecase(
        repository,
      ).execute(key).first;
      expect(repository.requested, key);
      expect(event.key, key);
      expect(event.phase, BitcoinSyncPhase.findingPeers);
    },
  );
}
