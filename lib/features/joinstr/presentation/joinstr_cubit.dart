import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/get_joinstr_settings_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/initiate_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/join_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/list_joinstr_pools_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/save_joinstr_relay_usecase.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Registered as a singleton and provided with `BlocProvider.value`: a round
/// blocks in the bindings for up to the pool duration, so the cubit must
/// outlive the screen. Were it closed on navigation, a finished round's txid
/// would be lost and the same coin could be offered to a second pool while
/// the first round is still signing with it.
class JoinstrCubit extends Cubit<JoinstrState> {
  JoinstrCubit({
    required GetWalletsUsecase getWalletsUsecase,
    required GetJoinstrSettingsUsecase getJoinstrSettingsUsecase,
    required SaveJoinstrRelayUsecase saveJoinstrRelayUsecase,
    required ListJoinstrPoolsUsecase listJoinstrPoolsUsecase,
    required JoinJoinstrPoolUsecase joinJoinstrPoolUsecase,
    required InitiateJoinstrPoolUsecase initiateJoinstrPoolUsecase,
  }) : _getWallets = getWalletsUsecase,
       _getSettings = getJoinstrSettingsUsecase,
       _saveRelay = saveJoinstrRelayUsecase,
       _listPools = listJoinstrPoolsUsecase,
       _joinPool = joinJoinstrPoolUsecase,
       _initiatePool = initiateJoinstrPoolUsecase,
       super(const JoinstrState());

  final GetWalletsUsecase _getWallets;
  final GetJoinstrSettingsUsecase _getSettings;
  final SaveJoinstrRelayUsecase _saveRelay;
  final ListJoinstrPoolsUsecase _listPools;
  final JoinJoinstrPoolUsecase _joinPool;
  final InitiateJoinstrPoolUsecase _initiatePool;

  Future<void> load() async {
    // A running round already holds live state; re-resolving the wallet or
    // resetting the error here would detach the UI from it.
    if (state.isRunning) return;

    final List<Wallet> candidates;
    try {
      final settings = await _getSettings.execute();
      _emit(state.copyWith(relay: settings.relay, history: settings.history));
      final wallets = await _getWallets.execute(onlyBitcoin: true);
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

    _emit(state.copyWith(wallet: supported));
    await refreshPools();
  }

  Future<void> refreshPools() async {
    if (state.isRunning) return;
    _emit(state.copyWith(status: JoinstrStatus.loadingPools, error: null));
    try {
      final pools = await _listPools.execute();
      _emit(state.copyWith(status: JoinstrStatus.idle, pools: pools));
    } catch (e) {
      _fail(_asJoinstrException(e));
    }
  }

  Future<void> relayChanged(String relay) async {
    try {
      await _saveRelay.execute(relay);
      _emit(state.copyWith(relay: relay.trim(), error: null));
      await refreshPools();
    } catch (e) {
      _fail(_asJoinstrException(e));
    }
  }

  void denominationChanged(String value) {
    if (value.isEmpty || Joinstr.denominationBtcPattern.hasMatch(value)) {
      _emit(state.copyWith(denominationBtc: value));
    }
  }

  void peersChanged(String value) =>
      _emit(state.copyWith(peers: _digitsOnly(value)));

  void feeRateChanged(String value) =>
      _emit(state.copyWith(feeRate: _digitsOnly(value)));

  Future<void> joinPool(JoinstrPool pool) async {
    final wallet = state.wallet;
    if (wallet == null || state.isRunning) return;

    final round = JoinstrRound(
      initiated: false,
      denominationSat: pool.denominationSat,
      peers: pool.peers,
      relay: pool.relay,
      feeRateSatPerVb: pool.feeRateSatPerVb,
      publicKey: pool.publicKey,
      expiresAtUnixSec: pool.expiresAtUnixSec,
    );
    _emit(state.copyWith(rounds: [round, ...state.rounds], error: null));

    try {
      final txId = await _joinPool.execute(wallet: wallet, pool: pool);
      await _completeWaitingRound(round.completed(txId));
    } catch (e) {
      _replaceWaitingRound(round.failed(_asJoinstrException(e)));
    }
  }

  Future<void> initiatePool() async {
    final wallet = state.wallet;
    if (wallet == null || state.isRunning) return;

    final denomination = Joinstr.parseDenominationBtcToSat(
      state.denominationBtc,
    );
    final peers = int.tryParse(state.peers) ?? 0;
    final feeRate = int.tryParse(state.feeRate) ?? 0;
    if (denomination == null || peers < 2 || feeRate <= 0) {
      _fail(JoinstrException(JoinstrIssue.invalidPoolConfig));
      return;
    }

    const maxDuration = Duration(hours: 1);
    final round = JoinstrRound(
      initiated: true,
      denominationSat: denomination,
      peers: peers,
      relay: state.relay,
      feeRateSatPerVb: feeRate,
      expiresAtUnixSec:
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + maxDuration.inSeconds,
    );
    _emit(state.copyWith(rounds: [round, ...state.rounds], error: null));

    try {
      final txId = await _initiatePool.execute(
        wallet: wallet,
        denominationSat: denomination,
        peers: peers,
        feeRateSatPerVb: feeRate,
        maxDuration: maxDuration,
      );
      await _completeWaitingRound(round.completed(txId));
    } catch (e) {
      _replaceWaitingRound(round.failed(_asJoinstrException(e)));
    }
  }

  Future<void> _completeWaitingRound(JoinstrRound completed) async {
    _replaceWaitingRound(completed);
    // The usecase already persisted the history entry; re-read it so the
    // History tab shows it without a manual refresh.
    try {
      final settings = await _getSettings.execute();
      _emit(state.copyWith(history: settings.history));
    } catch (_) {
      // The round itself succeeded; a failed history read must not turn the
      // broadcast into an error state.
    }
  }

  /// Only one round can ever be waiting (isRunning gates the rest), so the
  /// waiting entry is the one this outcome belongs to.
  void _replaceWaitingRound(JoinstrRound updated) {
    final rounds = [
      for (final r in state.rounds)
        if (r.isWaiting) updated else r,
    ];
    _emit(state.copyWith(rounds: rounds));
  }

  void _fail(JoinstrException e) =>
      _emit(state.copyWith(status: JoinstrStatus.error, error: e));

  void _emit(JoinstrState newState) {
    if (!isClosed) emit(newState);
  }

  JoinstrException _asJoinstrException(Object e) => e is JoinstrException
      ? e
      : JoinstrException(JoinstrIssue.coinjoinFailed, detail: e.toString());

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');
}
