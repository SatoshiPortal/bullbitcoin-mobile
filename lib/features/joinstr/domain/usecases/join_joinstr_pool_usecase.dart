import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_datasource.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_store.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_history_entry.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_peer_context_usecase.dart';

/// Joins an advertised pool. Blocks until the coinjoin broadcasts or the pool
/// times out, which can be the pool's full duration.
class JoinJoinstrPoolUsecase {
  final JoinstrDatasource _datasource;
  final JoinstrStore _store;
  final ResolveJoinstrPeerContextUsecase _resolvePeerContext;

  JoinJoinstrPoolUsecase({
    required this._datasource,
    required this._store,
    required ResolveJoinstrPeerContextUsecase resolvePeerContextUsecase,
  }) : _resolvePeerContext = resolvePeerContextUsecase;

  Future<String> execute({
    required Wallet wallet,
    required JoinstrPool pool,
  }) async {
    final context = await _resolvePeerContext.execute(wallet: wallet);

    log.info(
      'Joinstr joining pool ${pool.id}: '
      '${pool.denominationSat} sat, ${pool.peers} peers',
    );

    try {
      final txId = await _datasource.joinPool(
        pool: pool,
        wallet: wallet,
        mnemonic: context.mnemonic,
        outputAddress: context.outputAddress,
        electrumUrl: context.electrumUrl,
        proxy: context.proxy,
      );
      // Recorded here rather than in the cubit: a round outlives the screen
      // that started it, and its outcome must reach the history regardless.
      await _store.appendHistory(
        JoinstrHistoryEntry(
          amountSat: pool.denominationSat,
          txId: txId,
          relay: pool.relay,
          completedAtUnixSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      );
      // The reserved output address received this coinjoin: release it so the
      // next round gets a fresh one instead of reusing it on-chain.
      await _store.clearReservedAddress();
      return txId;
    } on JoinstrException {
      rethrow;
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      throw JoinstrException(JoinstrIssue.coinjoinFailed, detail: e.toString());
    }
  }
}
