import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_datasource.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_peer_context_usecase.dart';

/// Joins an advertised pool. Blocks until the coinjoin broadcasts or the pool
/// times out, which can be the pool's full duration.
class JoinJoinstrPoolUsecase {
  final JoinstrDatasource _datasource;
  final ResolveJoinstrPeerContextUsecase _resolvePeerContext;

  JoinJoinstrPoolUsecase({
    required this._datasource,
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
      return await _datasource.joinPool(
        pool: pool,
        wallet: wallet,
        mnemonic: context.mnemonic,
        outputAddress: context.outputAddress,
        electrumUrl: context.electrumUrl,
      );
    } on JoinstrException {
      rethrow;
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      throw JoinstrException(JoinstrIssue.coinjoinFailed, detail: e.toString());
    }
  }
}
