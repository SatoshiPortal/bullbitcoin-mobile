import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/complete_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/get_btcpay_connection_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/preview_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/btcpay/presentation/btcpay_pairing_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BtcpayPairingCubit extends Cubit<BtcpayPairingState> {
  final CompleteBtcpaySamRockPairingUsecase _completePairing;
  final GetBtcpayConnectionUsecase _getConnection;
  final PreviewBtcpaySamRockPairingUsecase _previewPairing;

  BtcpayPairingCubit({
    required this._completePairing,
    required this._getConnection,
    required this._previewPairing,
  }) : super(const BtcpayPairingState());

  Future<void> load() async {
    if (state.isSubmitting || state.connection != null) return;
    switch (await _getConnection.execute()) {
      case Ok(:final value):
        if (isClosed) return;
        emit(
          state.copyWith(
            status: BtcpayPairingStatus.idle,
            connection: value == null ? null : _connectionView(value),
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
        if (isClosed) return;
        emit(
          state.copyWith(
            status: BtcpayPairingStatus.success,
            connection: _connectionView(value),
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
}
