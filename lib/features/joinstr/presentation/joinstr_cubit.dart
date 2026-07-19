import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_coin.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_progress.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/get_joinstr_settings_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/initiate_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/join_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/list_joinstr_coins_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/list_joinstr_pools_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/save_joinstr_relay_usecase.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Registered as a singleton and provided with `BlocProvider.value`: a round
/// blocks in the bindings for up to the pool duration, so the cubit must
/// outlive the screen or a finished round's txid would be lost. Several rounds
/// can run at once, each on its own input coin.
class JoinstrCubit extends Cubit<JoinstrState> {
  JoinstrCubit({
    required GetWalletsUsecase getWalletsUsecase,
    required GetJoinstrSettingsUsecase getJoinstrSettingsUsecase,
    required SaveJoinstrRelayUsecase saveJoinstrRelayUsecase,
    required ListJoinstrPoolsUsecase listJoinstrPoolsUsecase,
    required ListJoinstrCoinsUsecase listJoinstrCoinsUsecase,
    required JoinJoinstrPoolUsecase joinJoinstrPoolUsecase,
    required InitiateJoinstrPoolUsecase initiateJoinstrPoolUsecase,
  }) : _getWallets = getWalletsUsecase,
       _getSettings = getJoinstrSettingsUsecase,
       _saveRelay = saveJoinstrRelayUsecase,
       _listPools = listJoinstrPoolsUsecase,
       _listCoins = listJoinstrCoinsUsecase,
       _joinPool = joinJoinstrPoolUsecase,
       _initiatePool = initiateJoinstrPoolUsecase,
       super(const JoinstrState());

  final GetWalletsUsecase _getWallets;
  final GetJoinstrSettingsUsecase _getSettings;
  final SaveJoinstrRelayUsecase _saveRelay;
  final ListJoinstrPoolsUsecase _listPools;
  final ListJoinstrCoinsUsecase _listCoins;
  final JoinJoinstrPoolUsecase _joinPool;
  final InitiateJoinstrPoolUsecase _initiatePool;

  int _nextRoundId = 0;

  Future<void> load() async {
    if (state.wallet != null) return; // already resolved for this session

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
    // Coins and pools both need Tor; kick them off together.
    await Future.wait([loadCoins(), refreshPools()]);
  }

  Future<void> loadCoins() async {
    final wallet = state.wallet;
    if (wallet == null) return;
    _emit(state.copyWith(loadingCoins: true, error: null));
    try {
      final coins = await _listCoins.execute(wallet: wallet);
      _emit(state.copyWith(coins: coins, loadingCoins: false));
    } catch (e) {
      _emit(state.copyWith(loadingCoins: false));
      _fail(_asJoinstrException(e));
    }
  }

  Future<void> refreshPools() async {
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
      // The eligible-coin set depends on the denomination, so a coin picked for
      // a different denomination may no longer qualify: drop it.
      _emit(state.copyWith(denominationBtc: value, selectedCoin: null));
    }
  }

  void peersChanged(String value) =>
      _emit(state.copyWith(peers: _digitsOnly(value)));

  void feeRateChanged(String value) =>
      _emit(state.copyWith(feeRate: _digitsOnly(value)));

  void selectCoin(JoinstrCoin? coin) =>
      _emit(state.copyWith(selectedCoin: coin));

  Future<void> initiatePool() async {
    final wallet = state.wallet;
    if (wallet == null) return;

    final peers = int.tryParse(state.peers) ?? 0;
    final feeRate = int.tryParse(state.feeRate) ?? 0;
    final coin = state.selectedCoin;
    // The denomination follows the chosen input: the coin's value minus the
    // fee surplus, so the coin is eligible by construction.
    final denomination = coin == null
        ? null
        : Joinstr.deriveDenominationSat(
            coinValueSat: coin.valueSat,
            feeRateSatPerVb: feeRate,
          );
    if (coin == null || peers < 2 || feeRate <= 0 || denomination == null) {
      _fail(JoinstrException(JoinstrIssue.invalidPoolConfig));
      return;
    }

    const maxDuration = Duration(hours: 1);
    final round = JoinstrRound(
      id: _nextRoundId++,
      initiated: true,
      denominationSat: denomination,
      peers: peers,
      relay: state.relay,
      feeRateSatPerVb: feeRate,
      inputOutpoint: coin.outpoint,
      expiresAtUnixSec:
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + maxDuration.inSeconds,
    );
    _emit(
      state.copyWith(
        rounds: [round, ...state.rounds],
        selectedCoin: null,
        error: null,
      ),
    );

    await _consume(
      round,
      _initiatePool.execute(
        wallet: wallet,
        denominationSat: denomination,
        peers: peers,
        feeRateSatPerVb: feeRate,
        inputOutpoint: coin.outpoint,
        maxDuration: maxDuration,
      ),
    );
  }

  Future<void> joinPool(JoinstrPool pool, JoinstrCoin coin) async {
    final wallet = state.wallet;
    if (wallet == null) return;

    final round = JoinstrRound(
      id: _nextRoundId++,
      initiated: false,
      denominationSat: pool.denominationSat,
      peers: pool.peers,
      relay: pool.relay,
      feeRateSatPerVb: pool.feeRateSatPerVb,
      inputOutpoint: coin.outpoint,
      publicKey: pool.publicKey,
      expiresAtUnixSec: pool.expiresAtUnixSec,
    );
    _emit(state.copyWith(rounds: [round, ...state.rounds], error: null));

    await _consume(
      round,
      _joinPool.execute(
        wallet: wallet,
        pool: pool,
        inputOutpoint: coin.outpoint,
      ),
    );
  }

  /// Drives a coinjoin's progress stream, advancing the round's step in state
  /// so the timeline updates live. On completion it refreshes coins (the input
  /// was spent) and history.
  Future<void> _consume(
    JoinstrRound round,
    Stream<JoinstrProgress> progress,
  ) async {
    // Updates build on the latest round, not the snapshot taken at stream
    // start, so a terminal update keeps the step the round had reached.
    var current = round;
    void update(JoinstrRound next) {
      current = next;
      _updateRound(next.id, next);
    }

    try {
      await for (final p in progress) {
        if (p.step == JoinstrRoundStep.done) {
          update(current.completed(p.txId ?? ''));
        } else if (p.step == JoinstrRoundStep.failed) {
          update(
            current.failed(
              JoinstrException(
                JoinstrIssue.coinjoinFailed,
                detail: p.errorMessage,
              ),
            ),
          );
        } else if (p.step != JoinstrRoundStep.other) {
          update(current.advancedTo(p.step));
        }
      }
    } catch (e) {
      update(current.failed(_asJoinstrException(e)));
    }

    // The bindings send the terminal update with its result ignored, so a
    // closed channel can end the stream without one. A round left waiting
    // here would spin forever and keep its coin excluded from the pickers.
    if (current.isWaiting) {
      update(
        current.failed(
          JoinstrException(
            JoinstrIssue.coinjoinFailed,
            detail: 'the coinjoin ended without a result',
          ),
        ),
      );
    }

    await loadCoins();
    try {
      final settings = await _getSettings.execute();
      _emit(state.copyWith(history: settings.history));
    } catch (_) {
      // A failed history/coin refresh must not clobber the round's outcome.
    }
  }

  void _updateRound(int id, JoinstrRound updated) {
    _emit(
      state.copyWith(
        rounds: [
          for (final r in state.rounds)
            if (r.id == id) updated else r,
        ],
      ),
    );
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
