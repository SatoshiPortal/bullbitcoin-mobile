import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_detail_state.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the invoice detail screen. It polls the UNSIGNED status endpoint with
/// exponential backoff (3s → cap ~30s, DG-I4), stops on a terminal status or on
/// dispose, and offers an unpaid-only cancel behind the screen's confirm
/// dialog. The cancel's final status is stored SEPARATELY from the polled
/// snapshot (§3.11).
class InvoiceDetailCubit extends Cubit<InvoiceDetailState> {
  final InvoicesFacade _facade;
  final InvoiceId _invoiceId;
  final Duration _pollInitialDelay;
  final Duration _pollMaxDelay;

  int _pollGeneration = 0;

  InvoiceDetailCubit({
    required this._facade,
    required this._invoiceId,
    Invoice? invoice,
    this._pollInitialDelay = const Duration(seconds: 3),
    this._pollMaxDelay = const Duration(seconds: 30),
  }) : super(InvoiceDetailState(invoice: invoice));

  /// First load then, unless already terminal, start the polling loop.
  Future<void> load() async {
    await _fetch();
    if (isClosed) return;
    if (!state.isTerminal && state.status == InvoiceDetailStatus.loaded) {
      unawaited(_poll(++_pollGeneration));
    }
  }

  /// Explicit pull-to-refresh (§3.18): a single fetch, no new poll loop.
  Future<void> refresh() => _fetch();

  Future<void> cancel() async {
    if (state.cancelling || !state.canCancel) return;
    emit(state.copyWith(cancelling: true, clearCancelFailure: true));
    try {
      final result = await _facade.cancel(
        CancelInvoiceCommand(
          invoiceId: _invoiceId,
          nymOwner: state.invoice?.nymOwner,
        ),
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          cancelling: false,
          cancelFinalStatus: result.finalStatus,
        ),
      );
      // Reflect the settled state (and stop polling once terminal).
      await _fetch();
    } on InvoicesException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(cancelling: false, cancelFailure: e));
      await _fetch();
    } catch (e, stack) {
      log.warning('Invoice cancel failed', error: e, trace: stack);
      if (isClosed) return;
      emit(
        state.copyWith(
          cancelling: false,
          cancelFailure: const InvoicesException.unexpected(),
        ),
      );
    }
  }

  Future<void> _fetch() async {
    try {
      final snapshot = await _facade.status(_invoiceId);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: InvoiceDetailStatus.loaded,
          snapshot: snapshot,
          clearFailure: true,
        ),
      );
    } on InvoicesException catch (e) {
      if (isClosed) return;
      // Keep a prior snapshot visible; only flip to error on the first load.
      if (state.snapshot == null) {
        emit(state.copyWith(status: InvoiceDetailStatus.error, failure: e));
      } else {
        emit(state.copyWith(failure: e));
      }
    } catch (e, stack) {
      log.warning('Invoice status load failed', error: e, trace: stack);
      if (isClosed) return;
      if (state.snapshot == null) {
        emit(
          state.copyWith(
            status: InvoiceDetailStatus.error,
            failure: const InvoicesException.unexpected(),
          ),
        );
      }
    }
  }

  Future<void> _poll(int generation) async {
    var delay = _pollInitialDelay;
    while (!isClosed && generation == _pollGeneration) {
      await Future<void>.delayed(delay);
      if (isClosed || generation != _pollGeneration) return;
      if (state.isTerminal) return;
      await _fetch();
      if (isClosed || state.isTerminal) return;
      final next = delay.inSeconds * 2;
      delay = Duration(
        seconds: next > _pollMaxDelay.inSeconds
            ? _pollMaxDelay.inSeconds
            : next,
      );
    }
  }

  @override
  Future<void> close() {
    // Invalidate the running poll loop (terminal-aware stop-on-dispose).
    _pollGeneration++;
    return super.close();
  }
}
