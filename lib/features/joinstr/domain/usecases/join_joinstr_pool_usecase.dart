import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_datasource.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_store.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_history_entry.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_progress.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_node_context_usecase.dart';

/// Joins an advertised pool with a user-chosen input coin, streaming coinjoin
/// progress until it broadcasts or the pool times out.
class JoinJoinstrPoolUsecase {
  final JoinstrDatasource _datasource;
  final JoinstrStore _store;
  final ResolveJoinstrNodeContextUsecase _resolveNodeContext;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;

  JoinJoinstrPoolUsecase({
    required this._datasource,
    required this._store,
    required ResolveJoinstrNodeContextUsecase resolveNodeContextUsecase,
    required this._getReceiveAddressUsecase,
  }) : _resolveNodeContext = resolveNodeContextUsecase;

  Stream<JoinstrProgress> execute({
    required Wallet wallet,
    required JoinstrPool pool,
    required String inputOutpoint,
  }) async* {
    final context = await _resolveNodeContext.execute(wallet: wallet);

    // A fresh receive address per pool, like the reference wallets.
    final address = await _getReceiveAddressUsecase.execute(
      walletId: wallet.id,
      generateNew: true,
    );

    log.info(
      'Joinstr joining pool ${pool.id}: '
      '${pool.denominationSat} sat, ${pool.peers} peers, input $inputOutpoint',
    );

    await for (final progress in _datasource.joinPool(
      pool: pool,
      wallet: wallet,
      mnemonic: context.mnemonic,
      outputAddress: address.address,
      electrumUrl: context.electrumUrl,
      inputOutpoint: inputOutpoint,
      proxy: context.proxy,
    )) {
      if (progress.step == JoinstrRoundStep.done && progress.txId != null) {
        await _store.appendHistory(
          JoinstrHistoryEntry(
            amountSat: pool.denominationSat,
            txId: progress.txId!,
            relay: pool.relay,
            completedAtUnixSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
      }
      yield progress;
    }
  }
}
