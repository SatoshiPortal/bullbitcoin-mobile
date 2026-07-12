import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/initiate_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/join_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/list_joinstr_pools_usecase.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class JoinstrCubit extends Cubit<JoinstrState> {
  JoinstrCubit({
    required this._getWalletsUsecase,
    required ListJoinstrPoolsUsecase listJoinstrPoolsUsecase,
    required JoinJoinstrPoolUsecase joinJoinstrPoolUsecase,
    required InitiateJoinstrPoolUsecase initiateJoinstrPoolUsecase,
  }) : _listPools = listJoinstrPoolsUsecase,
       _joinPool = joinJoinstrPoolUsecase,
       _initiatePool = initiateJoinstrPoolUsecase,
       super(const JoinstrState());

  final GetWalletsUsecase _getWalletsUsecase;
  final ListJoinstrPoolsUsecase _listPools;
  final JoinJoinstrPoolUsecase _joinPool;
  final InitiateJoinstrPoolUsecase _initiatePool;

  Future<void> load() async {
    final List<Wallet> candidates;
    try {
      final wallets = await _getWalletsUsecase.execute(onlyBitcoin: true);
      candidates = wallets.where((w) => w.signsLocally).toList();
    } catch (e) {
      _fail(_asJoinstrException(e));
      return;
    }
    if (candidates.isEmpty) {
      _fail(JoinstrException(JoinstrIssue.watchOnlyWallet));
      return;
    }

    // Take the first wallet joinstr can actually use rather than the first
    // hot wallet: someone holding both a mainnet and a testnet wallet should
    // land on the testnet one, not on "mainnet not supported".
    Wallet? supported;
    JoinstrException? rejection;
    for (final wallet in candidates) {
      try {
        Joinstr.assertWalletSupported(wallet);
        supported = wallet;
        break;
      } on JoinstrException catch (e) {
        rejection ??= e;
      }
    }
    if (supported == null) {
      _fail(rejection!);
      return;
    }

    if (!isClosed) emit(state.copyWith(wallet: supported));
    await refreshPools();
  }

  Future<void> refreshPools() async {
    if (state.isRunning) return;
    if (!isClosed) {
      emit(state.copyWith(status: JoinstrStatus.loadingPools, error: null));
    }
    try {
      final pools = await _listPools.execute();
      if (!isClosed) {
        emit(state.copyWith(status: JoinstrStatus.idle, pools: pools));
      }
    } catch (e) {
      _fail(_asJoinstrException(e));
    }
  }

  void denominationChanged(String value) =>
      emit(state.copyWith(denominationSat: _digitsOnly(value)));

  void peersChanged(String value) =>
      emit(state.copyWith(peers: _digitsOnly(value)));

  void feeRateChanged(String value) =>
      emit(state.copyWith(feeRate: _digitsOnly(value)));

  Future<void> joinPool(JoinstrPool pool) async {
    final wallet = state.wallet;
    if (wallet == null || state.isRunning) return;
    if (!isClosed) {
      emit(
        state.copyWith(
          status: JoinstrStatus.running,
          activePool: pool,
          error: null,
          txId: null,
        ),
      );
    }
    try {
      final txId = await _joinPool.execute(wallet: wallet, pool: pool);
      if (!isClosed) {
        emit(state.copyWith(status: JoinstrStatus.done, txId: txId));
      }
    } catch (e) {
      _fail(_asJoinstrException(e));
    }
  }

  Future<void> initiatePool() async {
    final wallet = state.wallet;
    if (wallet == null || state.isRunning) return;

    final denomination = int.tryParse(state.denominationSat) ?? 0;
    final peers = int.tryParse(state.peers) ?? 0;
    final feeRate = int.tryParse(state.feeRate) ?? 0;
    if (denomination <= 0 || peers < 2 || feeRate <= 0) {
      _fail(JoinstrException(JoinstrIssue.invalidPoolConfig));
      return;
    }

    if (!isClosed) {
      emit(
        state.copyWith(
          status: JoinstrStatus.running,
          activePool: null,
          error: null,
          txId: null,
        ),
      );
    }
    try {
      final txId = await _initiatePool.execute(
        wallet: wallet,
        denominationSat: denomination,
        peers: peers,
        feeRateSatPerVb: feeRate,
      );
      if (!isClosed) {
        emit(state.copyWith(status: JoinstrStatus.done, txId: txId));
      }
    } catch (e) {
      _fail(_asJoinstrException(e));
    }
  }

  void _fail(JoinstrException e) {
    if (!isClosed) emit(state.copyWith(status: JoinstrStatus.error, error: e));
  }

  JoinstrException _asJoinstrException(Object e) => e is JoinstrException
      ? e
      : JoinstrException(JoinstrIssue.coinjoinFailed, detail: e.toString());

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');
}
