import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';

enum InvoicesListStatus { initial, loading, loaded, error }

/// The invoices list screen state. The full server-loaded set is held in
/// [invoices]; [filter] is applied CLIENT-SIDE (prototype) so switching status
/// chips never re-hits the server. [hasMore] is tracked but not surfaced in v1
/// (no infinite scroll).
class InvoicesListState {
  final InvoicesListStatus status;
  final List<Invoice> invoices;
  final InvoiceStatus? filter;
  final bool hasMore;
  final bool fallbackSupervisionUnavailable;
  final bool fallbackSupervisionOverflow;
  final InvoicesFailure? failure;

  const InvoicesListState({
    this.status = InvoicesListStatus.initial,
    this.invoices = const [],
    this.filter,
    this.hasMore = false,
    this.fallbackSupervisionUnavailable = false,
    this.fallbackSupervisionOverflow = false,
    this.failure,
  });

  bool get isLoading => status == InvoicesListStatus.loading;

  /// The client-side filtered view rendered by the screen.
  List<Invoice> get visibleInvoices => filter == null
      ? invoices
      : invoices.where((invoice) => invoice.status == filter).toList();

  bool get isEmpty =>
      status == InvoicesListStatus.loaded && visibleInvoices.isEmpty;

  InvoicesListState copyWith({
    InvoicesListStatus? status,
    List<Invoice>? invoices,
    InvoiceStatus? filter,
    bool? hasMore,
    bool? fallbackSupervisionUnavailable,
    bool? fallbackSupervisionOverflow,
    InvoicesFailure? failure,
    bool clearFilter = false,
    bool clearFailure = false,
  }) {
    return InvoicesListState(
      status: status ?? this.status,
      invoices: invoices ?? this.invoices,
      filter: clearFilter ? null : filter ?? this.filter,
      hasMore: hasMore ?? this.hasMore,
      fallbackSupervisionUnavailable:
          fallbackSupervisionUnavailable ?? this.fallbackSupervisionUnavailable,
      fallbackSupervisionOverflow:
          fallbackSupervisionOverflow ?? this.fallbackSupervisionOverflow,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}
