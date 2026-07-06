import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';

/// The public status/detail view of an invoice (server `InvoiceStatusResponse`,
/// unsigned GET by id). Kept DISTINCT from [Invoice] (§3.11): the detail screen
/// merges this with the list [Invoice] explicitly, it never conflates them.
class InvoiceStatusSnapshot {
  final InvoiceStatus status;
  final String pricingMode;
  final String settlementStatus;
  final int amountSat;
  final int? fiatAmountMinor;
  final String? fiatCurrency;
  final int remainingAmountSat;
  final int paymentToleranceSat;
  final int? rateMinorPerBtc;
  final DateTime rateLocksUntil;
  final DateTime expiresAt;
  final PaymentMethod? paidVia;
  final DateTime? paidAt;
  final int? paidAmountSat;
  final String? lightningPr;
  final String? liquidAddress;
  final String? bitcoinAddress;
  final String? bitcoinChainAddress;
  final String? bitcoinChainBip21;
  final bool acceptBtc;
  final bool acceptLn;
  final bool acceptLiquid;

  const InvoiceStatusSnapshot({
    required this.status,
    required this.pricingMode,
    required this.settlementStatus,
    required this.amountSat,
    this.fiatAmountMinor,
    this.fiatCurrency,
    required this.remainingAmountSat,
    required this.paymentToleranceSat,
    this.rateMinorPerBtc,
    required this.rateLocksUntil,
    required this.expiresAt,
    this.paidVia,
    this.paidAt,
    this.paidAmountSat,
    this.lightningPr,
    this.liquidAddress,
    this.bitcoinAddress,
    this.bitcoinChainAddress,
    this.bitcoinChainBip21,
    required this.acceptBtc,
    required this.acceptLn,
    required this.acceptLiquid,
  });

  /// The status poll stops on a terminal status.
  bool get isTerminal => status.isTerminal;

  bool get isCancellable => status == InvoiceStatus.unpaid;

  Duration timeUntilExpiry(DateTime now) {
    final remaining = expiresAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
