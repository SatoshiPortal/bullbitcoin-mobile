import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_datasource.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_store.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_progress.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/joinstr_round_history.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_node_context_usecase.dart';

/// Announces a pool and takes part in it with a user-chosen input coin. Blocks
/// until the pool fills and the coinjoin broadcasts, or until [maxDuration]
/// elapses.
class InitiateJoinstrPoolUsecase {
  final JoinstrDatasource _datasource;
  final JoinstrStore _store;
  final ResolveJoinstrNodeContextUsecase _resolveNodeContext;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;

  InitiateJoinstrPoolUsecase({
    required this._datasource,
    required this._store,
    required ResolveJoinstrNodeContextUsecase resolveNodeContextUsecase,
    required this._getReceiveAddressUsecase,
  }) : _resolveNodeContext = resolveNodeContextUsecase;

  Stream<JoinstrProgress> execute({
    required Wallet wallet,
    required int denominationSat,
    required int peers,
    required int feeRateSatPerVb,
    required String inputOutpoint,
    Duration maxDuration = const Duration(hours: 1),
    String? relay,
  }) async* {
    final context = await _resolveNodeContext.execute(wallet: wallet);
    final poolRelay =
        relay ??
        await _store.getRelay() ??
        ApiServiceConstants.defaultNostrRelayUrl;

    // A fresh receive address per pool, like `getNewBech32Address()` in the
    // reference wallets: every pool the user runs receives its denominated
    // output to a distinct address.
    final address = await _getReceiveAddressUsecase.execute(
      walletId: wallet.id,
      generateNew: true,
    );

    log.info(
      'Joinstr initiating pool: $denominationSat sat, $peers peers, '
      '${feeRateSatPerVb}s/vB, input $inputOutpoint',
    );

    // Surface the output address up front so the timeline can show it from the
    // start; the datasource stream then carries the event ids, psbt and txid.
    yield JoinstrProgress(
      step: JoinstrRoundStep.connecting,
      outputAddress: address.address,
    );

    yield* recordHistoryOnDone(
      store: _store,
      amountSat: denominationSat,
      relay: poolRelay,
      progress: _datasource.initiatePool(
        wallet: wallet,
        mnemonic: context.mnemonic,
        outputAddress: address.address,
        electrumServers: context.electrumServers,
        relay: poolRelay,
        denominationSat: denominationSat,
        feeRateSatPerVb: feeRateSatPerVb,
        peers: peers,
        maxDuration: maxDuration,
        inputOutpoint: inputOutpoint,
        proxy: context.proxy,
      ),
    );
  }
}
