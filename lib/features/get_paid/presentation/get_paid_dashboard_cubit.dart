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
/// own identity). Invoices carry no "current" status and are a static tile, so
/// they are not read here.
class GetPaidDashboardCubit extends Cubit<GetPaidDashboardState> {
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
    emit(state.copyWith(isLoading: true, clearError: true));

    String? lightningAddress;
    bool lightningActive = false;
    String? nym;
    PaymentPage? paymentPage;
    PosTerminal? posTerminal;
    BtcpayConnection? btcpayConnection;
    String? refreshError;
    final invoicesWalletReady = await _hasDefaultWallet();

    try {
      final btcpayResult = await _btcpay.connection();
      switch (btcpayResult) {
        case Ok(:final value):
          btcpayConnection = value;
        case Err(:final failure):
          log.warning(
            'Get Paid dashboard could not load the BTCPay connection',
            error: failure.runtimeType,
          );
          refreshError = 'Something went wrong. Please try again.';
      }

      final registration = await _lightningAddress
          .lookupWalletOwnedRegistration();
      nym = registration.nym.isEmpty ? null : registration.nym;
      lightningActive = registration.active;
      // Decoupled from active: keep the address whenever the registration
      // carries one, so the subtitle can show it even while inactive.
      lightningAddress = (registration.lightningAddress?.isEmpty ?? true)
          ? null
          : registration.lightningAddress;

      if (nym != null) {
        if (_isStale(generation)) return;
        final page = await _paymentPage.find(nym: nym);
        paymentPage = page?.isArchived == true ? null : page;

        if (_isStale(generation)) return;
        final terminal = await _pos.find(nym: nym);
        posTerminal = terminal?.isArchived == true ? null : terminal;
      }

      if (_isStale(generation)) return;
      emit(
        _snapshot(
          lightningAddress: lightningAddress,
          lightningActive: lightningActive,
          nym: nym,
          paymentPage: paymentPage,
          posTerminal: posTerminal,
          btcpayConnection: btcpayConnection,
          invoicesWalletReady: invoicesWalletReady,
          error: refreshError,
        ),
      );
    } on Exception catch (e, stack) {
      if (_isStale(generation)) return;
      log.warning('Get Paid dashboard refresh failed', error: e, trace: stack);
      // Keep whatever partial reads succeeded before the failure; surface the
      // error so the screen can toast it.
      emit(
        _snapshot(
          lightningAddress: lightningAddress,
          lightningActive: lightningActive,
          nym: nym,
          paymentPage: paymentPage,
          posTerminal: posTerminal,
          btcpayConnection: btcpayConnection,
          invoicesWalletReady: invoicesWalletReady,
          error: 'Something went wrong. Please try again.',
        ),
      );
    }
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

  GetPaidDashboardState _snapshot({
    required String? lightningAddress,
    required bool lightningActive,
    required String? nym,
    required PaymentPage? paymentPage,
    required PosTerminal? posTerminal,
    required BtcpayConnection? btcpayConnection,
    required bool invoicesWalletReady,
    String? error,
  }) {
    return state.copyWith(
      isLoading: false,
      lightningAddress: lightningAddress,
      clearLightningAddress: lightningAddress == null,
      lightningActive: lightningActive,
      nym: nym,
      clearNym: nym == null,
      paymentPage: paymentPage,
      clearPaymentPage: paymentPage == null,
      posTerminal: posTerminal,
      clearPos: posTerminal == null,
      btcpayConnection: btcpayConnection,
      clearBtcpayConnection: btcpayConnection == null,
      invoicesWalletReady: invoicesWalletReady,
      error: error,
      clearError: error == null,
    );
  }

  bool _isStale(int generation) {
    return isClosed || generation != _refreshGeneration;
  }
}
