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
  final InvoicesException? failure;

  final bool cancelling;
  final InvoiceStatus? cancelFinalStatus;
  final InvoicesException? cancelFailure;

  const InvoiceDetailState({
    this.status = InvoiceDetailStatus.loading,
    this.invoice,
    this.snapshot,
    this.failure,
    this.cancelling = false,
    this.cancelFinalStatus,
    this.cancelFailure,
  });

  /// The current effective status: the settled cancel status wins over the
  /// polled snapshot once a cancel has completed.
  InvoiceStatus? get effectiveStatus => cancelFinalStatus ?? snapshot?.status;

  bool get isTerminal => effectiveStatus?.isTerminal ?? false;

  /// Cancel is offered only while unpaid (DG-I5), and never mid-cancel.
  bool get canCancel =>
      !cancelling &&
      cancelFinalStatus == null &&
      snapshot?.status == InvoiceStatus.unpaid;

  InvoiceDetailState copyWith({
    InvoiceDetailStatus? status,
    Invoice? invoice,
    InvoiceStatusSnapshot? snapshot,
    InvoicesException? failure,
    bool? cancelling,
    InvoiceStatus? cancelFinalStatus,
    InvoicesException? cancelFailure,
    bool clearFailure = false,
    bool clearCancelFailure = false,
  }) {
    return InvoiceDetailState(
      status: status ?? this.status,
      invoice: invoice ?? this.invoice,
      snapshot: snapshot ?? this.snapshot,
      failure: clearFailure ? null : failure ?? this.failure,
      cancelling: cancelling ?? this.cancelling,
      cancelFinalStatus: cancelFinalStatus ?? this.cancelFinalStatus,
      cancelFailure:
          clearCancelFailure ? null : cancelFailure ?? this.cancelFailure,
    );
  }
}
