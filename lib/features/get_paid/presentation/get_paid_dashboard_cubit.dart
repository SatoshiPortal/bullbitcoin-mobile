import 'package:bb_mobile/core/utils/logger.dart';
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
  int _refreshGeneration = 0;

  GetPaidDashboardCubit({
    required this._lightningAddress,
    required this._paymentPage,
    required this._pos,
    required this._btcpay,
  }) : super(const GetPaidDashboardState());

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    emit(state.copyWith(isLoading: true, clearError: true));

    String? lightningAddress;
    String? nym;
    PaymentPage? paymentPage;
    PosTerminal? posTerminal;
    BtcpayConnection? btcpayConnection;

    try {
      btcpayConnection = await _btcpay.connection();

      final registration = await _lightningAddress
          .lookupWalletOwnedRegistration();
      nym = registration.nym.isEmpty ? null : registration.nym;
      lightningAddress = registration.active
          ? registration.lightningAddress
          : null;

      if (nym != null) {
        if (_isStale(generation)) return;
        final page = await _paymentPage.find(nym: nym);
        paymentPage = page?.isArchived == true ? null : page;

        if (_isStale(generation)) return;
        final terminal = await _pos.find(nym: nym);
        posTerminal = terminal?.isArchived == true ? null : terminal;
      }

      if (_isStale(generation)) return;
      emit(_snapshot(
        lightningAddress: lightningAddress,
        nym: nym,
        paymentPage: paymentPage,
        posTerminal: posTerminal,
        btcpayConnection: btcpayConnection,
      ));
    } on Exception catch (e, stack) {
      if (_isStale(generation)) return;
      log.warning('Get Paid dashboard refresh failed', error: e, trace: stack);
      // Keep whatever partial reads succeeded before the failure; surface the
      // error so the screen can toast it.
      emit(_snapshot(
        lightningAddress: lightningAddress,
        nym: nym,
        paymentPage: paymentPage,
        posTerminal: posTerminal,
        btcpayConnection: btcpayConnection,
        error: 'Something went wrong. Please try again.',
      ));
    }
  }

  GetPaidDashboardState _snapshot({
    required String? lightningAddress,
    required String? nym,
    required PaymentPage? paymentPage,
    required PosTerminal? posTerminal,
    required BtcpayConnection? btcpayConnection,
    String? error,
  }) {
    return state.copyWith(
      isLoading: false,
      lightningAddress: lightningAddress,
      clearLightningAddress: lightningAddress == null,
      nym: nym,
      clearNym: nym == null,
      paymentPage: paymentPage,
      clearPaymentPage: paymentPage == null,
      posTerminal: posTerminal,
      clearPos: posTerminal == null,
      btcpayConnection: btcpayConnection,
      clearBtcpayConnection: btcpayConnection == null,
      error: error,
      clearError: error == null,
    );
  }

  bool _isStale(int generation) {
    return isClosed || generation != _refreshGeneration;
  }
}
