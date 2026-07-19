import 'package:bb_mobile/features/btcpay/public/btcpay_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';

enum GetPaidDashboardCardStatus { loading, loaded }

/// Read-only snapshot of every Get Paid product's status, assembled from the
/// public facades. Holds no money logic, no balances and no protocol internals
/// — only what the hub renders (a status chip + a contextual subtitle per
/// product).
class GetPaidDashboardState {
  final bool isLoading;
  final String? lightningAddress;

  /// True when the Lightning Address registration is ACTIVE. Decoupled from
  /// [lightningAddress]: the address may be present while the registration is
  /// inactive (subtitle shows the address; the status dot stays muted).
  final bool lightningActive;
  final String? nym;
  final PaymentPage? paymentPage;
  final PosTerminal? posTerminal;
  final BtcpayConnection? btcpayConnection;

  /// True when the user has a default wallet created — the Invoices product
  /// issues payouts from the default wallet, so this gates its "Active" status.
  final bool invoicesWalletReady;
  final String? error;
  final GetPaidDashboardCardStatus lightningStatus;
  final GetPaidDashboardCardStatus paymentPageStatus;
  final GetPaidDashboardCardStatus posStatus;
  final GetPaidDashboardCardStatus invoicesStatus;
  final GetPaidDashboardCardStatus btcpayStatus;

  const GetPaidDashboardState({
    this.isLoading = false,
    this.lightningAddress,
    this.lightningActive = false,
    this.nym,
    this.paymentPage,
    this.posTerminal,
    this.btcpayConnection,
    this.invoicesWalletReady = false,
    this.error,
    this.lightningStatus = GetPaidDashboardCardStatus.loading,
    this.paymentPageStatus = GetPaidDashboardCardStatus.loading,
    this.posStatus = GetPaidDashboardCardStatus.loading,
    this.invoicesStatus = GetPaidDashboardCardStatus.loading,
    this.btcpayStatus = GetPaidDashboardCardStatus.loading,
  });

  bool get hasLightningAddress =>
      lightningAddress != null && lightningAddress!.isNotEmpty;
  bool get hasPaymentPage => paymentPage != null && !paymentPage!.isArchived;
  bool get hasPos => posTerminal != null && !posTerminal!.isArchived;
  bool get hasBtcpayConnection => btcpayConnection != null;

  GetPaidDashboardState copyWith({
    bool? isLoading,
    String? lightningAddress,
    bool clearLightningAddress = false,
    bool? lightningActive,
    String? nym,
    bool clearNym = false,
    PaymentPage? paymentPage,
    bool clearPaymentPage = false,
    PosTerminal? posTerminal,
    bool clearPos = false,
    BtcpayConnection? btcpayConnection,
    bool clearBtcpayConnection = false,
    bool? invoicesWalletReady,
    String? error,
    bool clearError = false,
    GetPaidDashboardCardStatus? lightningStatus,
    GetPaidDashboardCardStatus? paymentPageStatus,
    GetPaidDashboardCardStatus? posStatus,
    GetPaidDashboardCardStatus? invoicesStatus,
    GetPaidDashboardCardStatus? btcpayStatus,
  }) {
    return GetPaidDashboardState(
      isLoading: isLoading ?? this.isLoading,
      lightningAddress: clearLightningAddress
          ? null
          : lightningAddress ?? this.lightningAddress,
      lightningActive: lightningActive ?? this.lightningActive,
      nym: clearNym ? null : nym ?? this.nym,
      paymentPage: clearPaymentPage ? null : paymentPage ?? this.paymentPage,
      posTerminal: clearPos ? null : posTerminal ?? this.posTerminal,
      btcpayConnection: clearBtcpayConnection
          ? null
          : btcpayConnection ?? this.btcpayConnection,
      invoicesWalletReady: invoicesWalletReady ?? this.invoicesWalletReady,
      error: clearError ? null : error ?? this.error,
      lightningStatus: lightningStatus ?? this.lightningStatus,
      paymentPageStatus: paymentPageStatus ?? this.paymentPageStatus,
      posStatus: posStatus ?? this.posStatus,
      invoicesStatus: invoicesStatus ?? this.invoicesStatus,
      btcpayStatus: btcpayStatus ?? this.btcpayStatus,
    );
  }
}
