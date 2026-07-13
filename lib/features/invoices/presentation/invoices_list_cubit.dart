import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_list_state.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the invoices list. It loads the npub's invoices with NO server-side
/// status filter (the filter is applied client-side over the loaded set), and
/// holds `hasMore` in state (v1 does not page). Reaches the feature only through
/// the [InvoicesFacade].
class InvoicesListCubit extends Cubit<InvoicesListState> {
  final InvoicesFacade _facade;

  InvoicesListCubit({required this._facade}) : super(const InvoicesListState());

  Future<void> load() => _fetch();

  Future<void> refresh() => _fetch();

  /// Client-side status filter (no wire call). Passing null clears it.
  void setFilter(InvoiceStatus? filter) {
    emit(
      filter == null
          ? state.copyWith(clearFilter: true)
          : state.copyWith(filter: filter),
    );
  }

  Future<void> _fetch() async {
    emit(
      state.copyWith(status: InvoicesListStatus.loading, clearFailure: true),
    );
    final result = await _facade.list(const ListInvoicesCommand());
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: InvoicesListStatus.loaded,
            invoices: value.invoices,
            hasMore: value.hasMore,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(status: InvoicesListStatus.error, failure: failure),
        );
    }
  }
}
