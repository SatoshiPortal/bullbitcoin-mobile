import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_datasource.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_peer_context_usecase.dart';

/// Announces a pool and takes part in it. Blocks until the pool fills and the
/// coinjoin broadcasts, or until [maxDuration] elapses.
class InitiateJoinstrPoolUsecase {
  final JoinstrDatasource _datasource;
  final ResolveJoinstrPeerContextUsecase _resolvePeerContext;

  InitiateJoinstrPoolUsecase({
    required this._datasource,
    required ResolveJoinstrPeerContextUsecase resolvePeerContextUsecase,
  }) : _resolvePeerContext = resolvePeerContextUsecase;

  Future<String> execute({
    required Wallet wallet,
    required int denominationSat,
    required int peers,
    required int feeRateSatPerVb,
    Duration maxDuration = const Duration(hours: 1),
    String? relay,
  }) async {
    final context = await _resolvePeerContext.execute(wallet: wallet);

    log.info(
      'Joinstr initiating pool: $denominationSat sat, $peers peers, '
      '${feeRateSatPerVb}s/vB',
    );

    try {
      return await _datasource.initiatePool(
        wallet: wallet,
        mnemonic: context.mnemonic,
        outputAddress: context.outputAddress,
        electrumUrl: context.electrumUrl,
        relay: relay ?? ApiServiceConstants.defaultNostrRelayUrl,
        denominationSat: denominationSat,
        feeRateSatPerVb: feeRateSatPerVb,
        peers: peers,
        maxDuration: maxDuration,
      );
    } on JoinstrException {
      rethrow;
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      throw JoinstrException(JoinstrIssue.coinjoinFailed, detail: e.toString());
    }
  }
}
