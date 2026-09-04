import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_completions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBoltzSwapRepository implements BoltzSwapRepository {
  List<Swap> swaps;
  final List<String> clearedSwapIds = [];
  final Map<String, SwapStatus?> updatedStatuses = {};

  FakeBoltzSwapRepository(this.swaps);

  @override
  Future<List<Swap>> getAllSwaps({String? walletId}) async => swaps;

  @override
  Future<Swap> updateSwapFields(
    String swapId, {
    SwapStatus? status,
    String? receiveTxid,
    String? refundTxid,
    String? receiveAddress,
    String? refundAddress,
    String? preimage,
    int? claimFee,
    int? refundFee,
    DateTime? completionTime,
    bool clearReceiveTxid = false,
  }) async {
    if (clearReceiveTxid) clearedSwapIds.add(swapId);
    updatedStatuses[swapId] = status;
    final swap = swaps.firstWhere((s) => s.id == swapId);
    return swap;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeWalletTransactionRepository implements WalletTransactionRepository {
  final Map<String, Set<String>> txidsByWallet;
  bool? lastSyncFlag;

  FakeWalletTransactionRepository(this.txidsByWallet);

  @override
  Future<List<WalletTransaction>> getWalletTransactions({
    String? txId,
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  }) async {
    lastSyncFlag = sync;
    final txids = txidsByWallet[walletId] ?? const <String>{};
    return [
      for (final txid in txids)
        WalletTransaction(
          walletId: walletId!,
          network: Network.bitcoinMainnet,
          direction: WalletTransactionDirection.incoming,
          status: WalletTransactionStatus.confirmed,
          txId: txid,
          amountSat: 1000,
          feeSat: 100,
          vsize: 100,
          inputs: const [],
          outputs: const [],
          isRbf: false,
        ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  ChainSwap chainSwap({
    String id = 'chn123456789',
    SwapStatus status = SwapStatus.completed,
    String? sendTxid = 'lockup-txid',
    String? receiveWalletId = 'w-receive',
    String? receiveTxid = 'claim-txid',
    String? refundTxid,
  }) =>
      Swap.chain(
            id: id,
            keyIndex: 0,
            type: SwapType.liquidToBitcoin,
            status: status,
            environment: Environment.mainnet,
            creationTime: DateTime(2026, 7),
            sendWalletId: 'w-send',
            paymentAddress: 'lq1...',
            paymentAmount: 100000,
            sendTxid: sendTxid,
            receiveWalletId: receiveWalletId,
            receiveTxid: receiveTxid,
            refundTxid: refundTxid,
          )
          as ChainSwap;

  VerifyChainSwapCompletionsUsecase usecase(
    FakeBoltzSwapRepository repo,
    Map<String, Set<String>> walletTxids,
  ) => VerifyChainSwapCompletionsUsecase(
    swapRepository: repo,
    walletTransactionRepository: FakeWalletTransactionRepository(walletTxids),
  );

  test(
    'retracts a recorded claim that is not in the receiving wallet',
    () async {
      // The D5gdAL9UI29W shape: completed, receiveTxid points at a tx that is
      // NOT ours (Boltz refunding its own lockup), user lockup still out there.
      final repo = FakeBoltzSwapRepository([chainSwap()]);

      await usecase(repo, {
        'w-receive': {'some-other-tx'},
      }).execute();

      expect(repo.clearedSwapIds, ['chn123456789']);
      // Reopened straight to refundable so the local (Boltz-independent)
      // refund drive picks it up.
      expect(repo.updatedStatuses['chn123456789'], SwapStatus.refundable);
    },
  );

  test('freshens the receive wallet before judging a recorded claim', () async {
    final repo = FakeBoltzSwapRepository([chainSwap()]);
    final wallets = FakeWalletTransactionRepository({
      'w-receive': {'some-other-tx'},
    });

    await VerifyChainSwapCompletionsUsecase(
      swapRepository: repo,
      walletTransactionRepository: wallets,
    ).execute();

    // A stale cache that predates the claim must never cause a retraction:
    // the lookup has to request a sync first.
    expect(wallets.lastSyncFlag, isTrue);
  });

  test('reopens an already-retracted completed swap as refundable', () async {
    // The state the 6.13.2 build leaves behind (user log 7HJNCXPK):
    // completed, receiveTxid already cleared, funds still locked. No
    // wallet lookup is possible or needed — reopen directly.
    final repo = FakeBoltzSwapRepository([chainSwap(receiveTxid: null)]);

    await usecase(repo, {}).execute();

    expect(repo.clearedSwapIds, isEmpty);
    expect(repo.updatedStatuses['chn123456789'], SwapStatus.refundable);
  });

  test(
    'keeps a completed swap whose claim is in the receiving wallet',
    () async {
      final repo = FakeBoltzSwapRepository([chainSwap()]);

      await usecase(repo, {
        'w-receive': {'claim-txid'},
      }).execute();

      expect(repo.clearedSwapIds, isEmpty);
    },
  );

  test(
    'skips when the receiving wallet has no transactions (not synced)',
    () async {
      final repo = FakeBoltzSwapRepository([chainSwap()]);

      await usecase(repo, {}).execute();

      expect(repo.clearedSwapIds, isEmpty);
    },
  );

  test(
    'skips external-address claims, refund-resolved and fundless swaps',
    () async {
      final repo = FakeBoltzSwapRepository([
        chainSwap(id: 'external1234', receiveWalletId: null),
        chainSwap(id: 'refunded1234', refundTxid: 'refund-txid'),
        chainSwap(id: 'fundless1234', sendTxid: null),
        chainSwap(id: 'ongoing12345', status: SwapStatus.claimable),
      ]);

      await usecase(repo, {
        'w-receive': {'unrelated-tx'},
      }).execute();

      expect(repo.clearedSwapIds, isEmpty);
    },
  );

  test('one failing swap does not stop the sweep', () async {
    // First swap's wallet lookup throws (wallet metadata gone); the second
    // must still be retracted.
    final repo = FakeBoltzSwapRepository([
      chainSwap(id: 'brokenwallet', receiveWalletId: 'w-missing'),
      chainSwap(id: 'chn123456789'),
    ]);
    final throwingWallets = _ThrowingWalletTransactionRepository(
      throwForWalletId: 'w-missing',
      txidsByWallet: {
        'w-receive': {'some-other-tx'},
      },
    );

    await VerifyChainSwapCompletionsUsecase(
      swapRepository: repo,
      walletTransactionRepository: throwingWallets,
    ).execute();

    expect(repo.clearedSwapIds, ['chn123456789']);
  });
}

class _ThrowingWalletTransactionRepository
    extends FakeWalletTransactionRepository {
  final String throwForWalletId;

  _ThrowingWalletTransactionRepository({
    required this.throwForWalletId,
    required Map<String, Set<String>> txidsByWallet,
  }) : super(txidsByWallet);

  @override
  Future<List<WalletTransaction>> getWalletTransactions({
    String? txId,
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  }) {
    if (walletId == throwForWalletId) {
      throw Exception('Wallet metadata not found');
    }
    return super.getWalletTransactions(
      txId: txId,
      walletId: walletId,
      toAddress: toAddress,
      environment: environment,
      sync: sync,
    );
  }
}
