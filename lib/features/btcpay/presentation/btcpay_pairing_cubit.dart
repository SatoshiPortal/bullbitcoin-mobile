import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/complete_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/get_btcpay_connection_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/get_btcpay_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/preview_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/btcpay/presentation/btcpay_pairing_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BtcpayPairingCubit extends Cubit<BtcpayPairingState> {
  final CompleteBtcpaySamRockPairingUsecase _completePairing;
  final GetBtcpayConnectionUsecase _getConnection;
  final GetBtcpayWalletBehaviorsUsecase _getWalletBehaviors;
  final PreviewBtcpaySamRockPairingUsecase _previewPairing;
  final UpdateWalletBehaviorUsecase _updateWalletBehavior;

  BtcpayPairingCubit({
    required this._completePairing,
    required this._getConnection,
    required this._getWalletBehaviors,
    required this._previewPairing,
    required this._updateWalletBehavior,
  }) : super(const BtcpayPairingState());

  Future<void> load() async {
    if (state.isSubmitting || state.connection != null) return;
    switch (await _getConnection.execute()) {
      case Ok(:final value):
        final walletBehaviors = value == null
            ? const <BtcpayWalletBehaviorViewModel>[]
            : await _loadWalletBehaviors(value);
        if (isClosed) return;
        emit(
          state.copyWith(
            status: BtcpayPairingStatus.idle,
            connection: value == null ? null : _connectionView(value),
            walletBehaviors: walletBehaviors,
            clearConnection: value == null,
          ),
        );
      case Err(:final failure):
        log.warning(
          'Failed to load the BTCPay connection',
          error: failure.runtimeType,
        );
        if (isClosed) return;
        emit(state.copyWith(status: BtcpayPairingStatus.idle));
    }
  }

  BtcpayPairingPreview? preview(String pairingUrl) {
    switch (_previewPairing.execute(pairingUrl)) {
      case Ok(:final value):
        return BtcpayPairingPreview(
          serverUrl: value.serverUrl,
          supportsBitcoinChain: value.supportsBitcoinChain,
          supportsLiquidChain: value.supportsLiquidChain,
          supportsLightning: value.supportsLightning,
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: BtcpayPairingStatus.failure,
            failure: failure,
            showPairingForm: state.connection == null,
          ),
        );
        return null;
    }
  }

  void pairNew() {
    if (state.isSubmitting) return;
    emit(
      state.copyWith(
        status: BtcpayPairingStatus.idle,
        clearFailure: true,
        showPairingForm: true,
      ),
    );
  }

  void clearPairingFailure() {
    if (state.isSubmitting || state.failure == null) return;
    emit(
      state.copyWith(
        status: BtcpayPairingStatus.idle,
        clearFailure: true,
        showPairingForm: true,
      ),
    );
  }

  Future<void> submit(String pairingUrl) async {
    if (state.isSubmitting) return;
    emit(
      state.copyWith(
        status: BtcpayPairingStatus.submitting,
        clearFailure: true,
        showPairingForm: true,
      ),
    );

    switch (await _completePairing.execute(pairingUrl: pairingUrl)) {
      case Ok(:final value):
        final walletBehaviors = await _loadWalletBehaviors(value);
        if (isClosed) return;
        emit(
          state.copyWith(
            status: BtcpayPairingStatus.success,
            connection: _connectionView(value),
            walletBehaviors: walletBehaviors,
            showPairingForm: false,
          ),
        );
      case Err(:final failure):
        if (isClosed) return;
        final connection = await _connectionAfterPairingFailure();
        if (isClosed) return;
        emit(
          state.copyWith(
            status: BtcpayPairingStatus.failure,
            failure: failure,
            connection: connection,
            clearConnection: connection == null,
            showPairingForm: connection == null,
          ),
        );
    }
  }

  Future<void> updateWalletBehavior({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) async {
    if (state.walletSettingsSaving) return;
    final previous = state.walletBehaviors;
    final updated = previous
        .map((behavior) {
          if (behavior.walletId != walletId) return behavior;
          return behavior.copyWith(
            hideOnHome: hideOnHome,
            autoSweepEnabled: autoSweepEnabled,
          );
        })
        .toList(growable: false);
    emit(state.copyWith(walletBehaviors: updated, walletSettingsSaving: true));
    try {
      await _updateWalletBehavior.execute(
        walletId: walletId,
        hideOnHome: hideOnHome,
        autoSweepEnabled: autoSweepEnabled,
      );
      final walletBehaviors = await _loadWalletBehaviors();
      if (isClosed) return;
      emit(
        state.copyWith(
          walletBehaviors: walletBehaviors,
          walletSettingsSaving: false,
        ),
      );
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to update BTCPay wallet behavior',
        error: error.runtimeType,
        trace: trace,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: BtcpayPairingStatus.failure,
          failure: const BtcpayUnexpectedFailure(),
          walletBehaviors: previous,
          walletSettingsSaving: false,
        ),
      );
    }
  }

  /// Storage remains authoritative after every pairing failure. In particular,
  /// an explicit rejection must not hide an older valid connection, while an
  /// uncertain submission reloads the supervision record saved by the usecase.
  Future<BtcpayConnectionViewModel?> _connectionAfterPairingFailure() async {
    return switch (await _getConnection.execute()) {
      Ok(:final value) => value == null ? null : _connectionView(value),
      Err(:final failure) => () {
        log.warning(
          'Failed to reload the BTCPay connection after pairing failure',
          error: failure.runtimeType,
        );
        // A load failure does not prove absence. Retain the last in-memory
        // connection instead of hiding it.
        return state.connection;
      }(),
    };
  }

  BtcpayConnectionViewModel _connectionView(BtcpayConnection connection) {
    return BtcpayConnectionViewModel(
      serverUrl: connection.serverUrl,
      storeId: connection.storeId,
      rails: [
        if (connection.supportsBitcoinChain) BtcpayPairingRail.bitcoin,
        if (connection.supportsLiquidChain) BtcpayPairingRail.liquid,
        if (connection.supportsLightning) BtcpayPairingRail.lightning,
      ],
      wallets: connection.walletNetworks
          .map((network) {
            return switch (network) {
              BtcpayWalletNetwork.bitcoin => BtcpayPairingWallet.bitcoin,
              BtcpayWalletNetwork.liquid => BtcpayPairingWallet.liquid,
            };
          })
          .toList(growable: false),
      isUncertain: connection.isUncertain,
      isPaired: connection.isPaired,
      displayDate: connection.pairedAt ?? connection.updatedAt,
    );
  }

  Future<List<BtcpayWalletBehaviorViewModel>> _loadWalletBehaviors([
    BtcpayConnection? connection,
  ]) async {
    try {
      BtcpayConnection? btcpayConnection = connection;
      if (btcpayConnection == null) {
        switch (await _getConnection.execute()) {
          case Ok(:final value):
            btcpayConnection = value;
          case Err(:final failure):
            log.warning(
              'Failed to load the BTCPay connection for wallet settings',
              error: failure.runtimeType,
            );
            return const [];
        }
      }
      final behaviors = await _getWalletBehaviors.execute(
        connection: btcpayConnection,
      );
      return behaviors.map((behavior) {
        return BtcpayWalletBehaviorViewModel(
          walletId: behavior.wallet.id,
          wallet: switch (behavior.network) {
            BtcpayWalletNetwork.bitcoin => BtcpayPairingWallet.bitcoin,
            BtcpayWalletNetwork.liquid => BtcpayPairingWallet.liquid,
          },
          hideOnHome: behavior.wallet.hideOnHome,
          autoSweepEnabled: behavior.wallet.autoSweepEnabled,
        );
      }).toList();
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to load BTCPay wallet behavior settings',
        error: error.runtimeType,
        trace: trace,
      );
      return const [];
    }
  }
}
