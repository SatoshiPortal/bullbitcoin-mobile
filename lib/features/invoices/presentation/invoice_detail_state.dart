import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';

enum InvoiceDetailStatus { loading, loaded, error }

/// The invoice detail state. [snapshot] is the public status shape; the cancel
/// result is kept SEPARATELY ([cancelFinalStatus]) so the two are never
/// conflated (§3.11). [invoice] is the optional list row the detail was opened
/// from (for fields the status endpoint does not carry, e.g. the share URL /
/// recipient).
class InvoiceDetailState {
  final InvoiceDetailStatus status;
  final Invoice? invoice;
  final InvoiceStatusSnapshot? snapshot;
  final InvoicesFailure? failure;
  final PrivateInvoiceLink? privateLink;
  final bool privateLinkLookupComplete;
  final List<InvoiceFallbackSupervision> fallbackSupervisions;
  final bool fallbackSupervisionOverflow;
  final InvoicesFailure? fallbackSupervisionFailure;

  final PaymentMethod? selectedQuoteRail;
  final InvoiceQuote? quote;
  final bool quoteRefreshing;
  final InvoicesFailure? quoteFailure;

  final bool cancelling;
  final InvoiceStatus? cancelFinalStatus;
  final InvoicesFailure? cancelFailure;

  const InvoiceDetailState({
    this.status = InvoiceDetailStatus.loading,
    this.invoice,
    this.snapshot,
    this.failure,
    this.privateLink,
    this.privateLinkLookupComplete = false,
    this.fallbackSupervisions = const [],
    this.fallbackSupervisionOverflow = false,
    this.fallbackSupervisionFailure,
    this.selectedQuoteRail,
    this.quote,
    this.quoteRefreshing = false,
    this.quoteFailure,
    this.cancelling = false,
    this.cancelFinalStatus,
    this.cancelFailure,
  });

  /// The current effective status: the settled cancel status wins over the
  /// polled snapshot once a cancel has completed.
  InvoiceStatus? get effectiveStatus => cancelFinalStatus ?? snapshot?.status;

  InvoiceFallbackState? get fallbackState =>
      mostUrgentInvoiceFallbackState(fallbackSupervisions);

  bool get isTerminal {
    final invoiceTerminal = cancelFinalStatus != null
        ? cancelFinalStatus!.isTerminal
        : snapshot?.isMonitoringComplete ?? false;
    if (!invoiceTerminal) return false;
    if (fallbackSupervisions.isEmpty) return true;
    return fallbackSupervisions.every(
      (item) => item.state == InvoiceFallbackState.settled,
    );
  }

  /// Cancel is offered only while unpaid (DG-I5), and never mid-cancel.
  bool get canCancel =>
      !cancelling &&
      cancelFinalStatus == null &&
      snapshot?.status == InvoiceStatus.unpaid;

  bool hasUsableQuote(DateTime now) =>
      quote != null && !quote!.isExpired(now) && !quoteRefreshing;

  InvoiceDetailState copyWith({
    InvoiceDetailStatus? status,
    Invoice? invoice,
    InvoiceStatusSnapshot? snapshot,
    InvoicesFailure? failure,
    PrivateInvoiceLink? privateLink,
    bool? privateLinkLookupComplete,
    List<InvoiceFallbackSupervision>? fallbackSupervisions,
    bool? fallbackSupervisionOverflow,
    InvoicesFailure? fallbackSupervisionFailure,
    PaymentMethod? selectedQuoteRail,
    InvoiceQuote? quote,
    bool? quoteRefreshing,
    InvoicesFailure? quoteFailure,
    bool? cancelling,
    InvoiceStatus? cancelFinalStatus,
    InvoicesFailure? cancelFailure,
    bool clearFailure = false,
    bool clearFallbackSupervisionFailure = false,
    bool clearQuote = false,
    bool clearQuoteFailure = false,
    bool clearCancelFailure = false,
  }) {
    return InvoiceDetailState(
      status: status ?? this.status,
      invoice: invoice ?? this.invoice,
      snapshot: snapshot ?? this.snapshot,
      failure: clearFailure ? null : failure ?? this.failure,
      privateLink: privateLink ?? this.privateLink,
      privateLinkLookupComplete:
          privateLinkLookupComplete ?? this.privateLinkLookupComplete,
      fallbackSupervisions: fallbackSupervisions ?? this.fallbackSupervisions,
      fallbackSupervisionOverflow:
          fallbackSupervisionOverflow ?? this.fallbackSupervisionOverflow,
      fallbackSupervisionFailure: clearFallbackSupervisionFailure
          ? null
          : fallbackSupervisionFailure ?? this.fallbackSupervisionFailure,
      selectedQuoteRail: selectedQuoteRail ?? this.selectedQuoteRail,
      quote: clearQuote ? null : quote ?? this.quote,
      quoteRefreshing: quoteRefreshing ?? this.quoteRefreshing,
      quoteFailure: clearQuoteFailure
          ? null
          : quoteFailure ?? this.quoteFailure,
      cancelling: cancelling ?? this.cancelling,
      cancelFinalStatus: cancelFinalStatus ?? this.cancelFinalStatus,
      cancelFailure: clearCancelFailure
          ? null
          : cancelFailure ?? this.cancelFailure,
    );
  }
}
