import 'package:bb_mobile/features/btcpay/public/btcpay_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';

/// Read-only snapshot of every Get Paid product's status, assembled from the
/// public facades. Holds no money logic, no balances and no protocol internals
/// — only what the hub renders (a status chip + a contextual subtitle per
/// product). Invoices carry no per-product "current" status, so they have no
/// field here (the tile is a static entry).
class GetPaidDashboardState {
  final bool isLoading;
  final String? lightningAddress;
  final String? nym;
  final PaymentPage? paymentPage;
  final PosTerminal? posTerminal;
  final BtcpayConnection? btcpayConnection;
  final String? error;

  const GetPaidDashboardState({
    this.isLoading = false,
    this.lightningAddress,
    this.nym,
    this.paymentPage,
    this.posTerminal,
    this.btcpayConnection,
    this.error,
  });

  bool get hasLightningAddress =>
      lightningAddress != null && lightningAddress!.isNotEmpty;
  bool get hasPaymentPage => paymentPage != null && !paymentPage!.isArchived;
  bool get hasPos => posTerminal != null && !posTerminal!.isArchived;
  bool get hasBtcpayConnection => btcpayConnection != null;

  /// True before the first successful load has populated any product — the cue
  /// to show the shimmer placeholder rather than the (empty) card list.
  bool get isFirstLoad =>
      isLoading &&
      lightningAddress == null &&
      paymentPage == null &&
      posTerminal == null &&
      btcpayConnection == null;

  GetPaidDashboardState copyWith({
    bool? isLoading,
    String? lightningAddress,
    bool clearLightningAddress = false,
    String? nym,
    bool clearNym = false,
    PaymentPage? paymentPage,
    bool clearPaymentPage = false,
    PosTerminal? posTerminal,
    bool clearPos = false,
    BtcpayConnection? btcpayConnection,
    bool clearBtcpayConnection = false,
    String? error,
    bool clearError = false,
  }) {
    return GetPaidDashboardState(
      isLoading: isLoading ?? this.isLoading,
      lightningAddress: clearLightningAddress
          ? null
          : lightningAddress ?? this.lightningAddress,
      nym: clearNym ? null : nym ?? this.nym,
      paymentPage: clearPaymentPage ? null : paymentPage ?? this.paymentPage,
      posTerminal: clearPos ? null : posTerminal ?? this.posTerminal,
      btcpayConnection: clearBtcpayConnection
          ? null
          : btcpayConnection ?? this.btcpayConnection,
      error: clearError ? null : error ?? this.error,
    );
  }
}
