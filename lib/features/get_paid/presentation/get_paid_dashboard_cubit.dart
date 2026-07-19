import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/btcpay/public/btcpay_facade.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_dashboard_state.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Assembles the Get Paid hub snapshot from the public facades only. It reads
/// each product's current status to render a chip + subtitle; it never touches
/// balances, protocol internals or money logic, and it never writes.
///
/// The Donation Page and Point of Sale rows are keyed by the wallet nym, which
/// is resolved from the Lightning Address registration — so those two are only
/// probed once a nym exists (mirroring how the product screens resolve their
/// own identity). Invoices only need the local default-wallet readiness check.
class GetPaidDashboardCubit extends Cubit<GetPaidDashboardState> {
  static const _nymNotFoundCode = 'NymNotFound';

  final LightningAddressFacade _lightningAddress;
  final PaymentPageFacade _paymentPage;
  final PosFacade _pos;
  final BtcpayFacade _btcpay;
  final GetWalletsUsecase _getWallets;
  int _refreshGeneration = 0;

  GetPaidDashboardCubit({
    required this._lightningAddress,
    required this._paymentPage,
    required this._pos,
    required this._btcpay,
    required this._getWallets,
  }) : super(const GetPaidDashboardState());

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        lightningStatus: GetPaidDashboardCardStatus.loading,
        paymentPageStatus: GetPaidDashboardCardStatus.loading,
        posStatus: GetPaidDashboardCardStatus.loading,
        invoicesStatus: GetPaidDashboardCardStatus.loading,
        btcpayStatus: GetPaidDashboardCardStatus.loading,
      ),
    );

    var failed = false;
    void recordFailure(String message, {Object? error, StackTrace? trace}) {
      failed = true;
      log.warning(message, error: error, trace: trace);
    }

    final invoicesFuture = () async {
      final ready = await _hasDefaultWallet();
      if (_isStale(generation)) return;
      emit(
        state.copyWith(
          invoicesWalletReady: ready,
          invoicesStatus: GetPaidDashboardCardStatus.loaded,
        ),
      );
    }();

    final btcpayFuture = () async {
      try {
        final result = await _btcpay.connection();
        if (_isStale(generation)) return;
        switch (result) {
          case Ok(:final value):
            emit(
              state.copyWith(
                btcpayConnection: value,
                clearBtcpayConnection: value == null,
                btcpayStatus: GetPaidDashboardCardStatus.loaded,
              ),
            );
          case Err(:final failure):
            recordFailure(
              'Get Paid dashboard could not load the BTCPay connection',
              error: failure.runtimeType,
            );
            emit(
              state.copyWith(btcpayStatus: GetPaidDashboardCardStatus.loaded),
            );
        }
      } on Exception catch (error, trace) {
        if (_isStale(generation)) return;
        recordFailure(
          'Get Paid dashboard BTCPay lookup failed',
          error: error,
          trace: trace,
        );
        emit(state.copyWith(btcpayStatus: GetPaidDashboardCardStatus.loaded));
      }
    }();

    final lightningAndSurfacesFuture = () async {
      LightningAddressStatus registration;
      try {
        registration = await _lightningAddress.lookupWalletOwnedRegistration();
      } on LightningAddressException catch (error, trace) {
        if (error.code == _nymNotFoundCode) {
          registration = const LightningAddressStatus(nym: '', active: false);
        } else {
          if (_isStale(generation)) return;
          recordFailure(
            'Get Paid dashboard Lightning Address lookup failed',
            error: error,
            trace: trace,
          );
          emit(
            state.copyWith(
              lightningStatus: GetPaidDashboardCardStatus.loaded,
              paymentPageStatus: GetPaidDashboardCardStatus.loaded,
              posStatus: GetPaidDashboardCardStatus.loaded,
            ),
          );
          return;
        }
      } on Exception catch (error, trace) {
        if (_isStale(generation)) return;
        recordFailure(
          'Get Paid dashboard Lightning Address lookup failed',
          error: error,
          trace: trace,
        );
        emit(
          state.copyWith(
            lightningStatus: GetPaidDashboardCardStatus.loaded,
            paymentPageStatus: GetPaidDashboardCardStatus.loaded,
            posStatus: GetPaidDashboardCardStatus.loaded,
          ),
        );
        return;
      }
      if (_isStale(generation)) return;

      final nym = registration.nym.isEmpty ? null : registration.nym;
      final address = (registration.lightningAddress?.isEmpty ?? true)
          ? null
          : registration.lightningAddress;
      emit(
        state.copyWith(
          lightningAddress: address,
          clearLightningAddress: address == null,
          lightningActive: registration.active,
          nym: nym,
          clearNym: nym == null,
          lightningStatus: GetPaidDashboardCardStatus.loaded,
        ),
      );

      if (nym == null) {
        emit(
          state.copyWith(
            clearPaymentPage: true,
            clearPos: true,
            paymentPageStatus: GetPaidDashboardCardStatus.loaded,
            posStatus: GetPaidDashboardCardStatus.loaded,
          ),
        );
        return;
      }

      final pageFuture = () async {
        try {
          final page = await _paymentPage.find(nym: nym);
          if (_isStale(generation)) return;
          final visiblePage = page?.isArchived == true ? null : page;
          emit(
            state.copyWith(
              paymentPage: visiblePage,
              clearPaymentPage: visiblePage == null,
              paymentPageStatus: GetPaidDashboardCardStatus.loaded,
            ),
          );
        } on Exception catch (error, trace) {
          if (_isStale(generation)) return;
          recordFailure(
            'Get Paid dashboard Donation Page lookup failed',
            error: error,
            trace: trace,
          );
          emit(
            state.copyWith(
              paymentPageStatus: GetPaidDashboardCardStatus.loaded,
            ),
          );
        }
      }();
      final posFuture = () async {
        try {
          final terminal = await _pos.find(nym: nym);
          if (_isStale(generation)) return;
          final visibleTerminal = terminal?.isArchived == true
              ? null
              : terminal;
          emit(
            state.copyWith(
              posTerminal: visibleTerminal,
              clearPos: visibleTerminal == null,
              posStatus: GetPaidDashboardCardStatus.loaded,
            ),
          );
        } on Exception catch (error, trace) {
          if (_isStale(generation)) return;
          recordFailure(
            'Get Paid dashboard Point of Sale lookup failed',
            error: error,
            trace: trace,
          );
          emit(state.copyWith(posStatus: GetPaidDashboardCardStatus.loaded));
        }
      }();
      await Future.wait([pageFuture, posFuture]);
    }();

    await Future.wait([
      invoicesFuture,
      btcpayFuture,
      lightningAndSurfacesFuture,
    ]);
    if (_isStale(generation)) return;
    emit(
      state.copyWith(
        isLoading: false,
        error: failed ? 'Something went wrong. Please try again.' : null,
        clearError: !failed,
      ),
    );
  }

  /// Whether the user has at least one default wallet — the Invoices product
  /// pays out from the default wallet, mirroring [CreateInvoiceUsecase]'s
  /// `onlyDefaults: true` resolution. Never throws: a missing-wallet failure
  /// simply means "not ready", and it must not abort the dashboard refresh.
  Future<bool> _hasDefaultWallet() async {
    try {
      final wallets = await _getWallets.execute(onlyDefaults: true);
      return wallets.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _isStale(int generation) {
    return isClosed || generation != _refreshGeneration;
  }
}
