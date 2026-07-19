import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_detail_state.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the invoice detail screen.
/// Polling uses exponential backoff (3s → cap ~30s, DG-I4) and stops only after lifecycle and settlement supervision are complete or on dispose.
/// Unpaid cancellation remains behind the screen's confirmation dialog, and its final status is stored separately from the polled snapshot (§3.11).
class InvoiceDetailCubit extends Cubit<InvoiceDetailState> {
  final InvoicesFacade _facade;
  final InvoiceId _invoiceId;
  final Duration _pollInitialDelay;
  final Duration _pollMaxDelay;
  final DateTime Function() _now;

  int _pollGeneration = 0;
  int _quoteOperation = 0;
  Timer? _quoteExpiryTimer;
  InvoiceQuote? _lastAcceptedQuote;
  final Map<PaymentMethod, String> _acceptedInstructionFingerprints = {};

  InvoiceDetailCubit({
    required this._facade,
    required this._invoiceId,
    Invoice? invoice,
    this._pollInitialDelay = const Duration(seconds: 3),
    this._pollMaxDelay = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc()),
       super(
         InvoiceDetailState(
           invoice: invoice,
           fallbackSupervisions: invoice?.fallbackSupervisions ?? const [],
         ),
       );

  /// First load then, unless monitoring is complete, start the polling loop.
  Future<void> load() async {
    unawaited(_loadPrivateLink());
    await _fetch();
    if (isClosed) return;
    if (!state.isTerminal && state.status == InvoiceDetailStatus.loaded) {
      unawaited(_poll(++_pollGeneration));
    }
    // Settlement polling is already running, so a slow provider quote cannot
    // delay money supervision even though initial page setup awaits its result.
    await _ensureInitialQuote();
  }

  /// Explicit pull-to-refresh (§3.18): a single fetch, no new poll loop.
  Future<void> refresh() => _fetch();

  Future<void> _loadPrivateLink() async {
    try {
      final link = await _facade.privateLink(_invoiceId);
      if (!isClosed) {
        emit(
          state.copyWith(privateLink: link, privateLinkLookupComplete: true),
        );
      }
    } on Object {
      if (!isClosed) {
        emit(state.copyWith(privateLinkLookupComplete: true));
      }
    }
  }

  Future<void> selectQuoteRail(PaymentMethod rail) => refreshQuote(rail);

  Future<void> refreshQuote(PaymentMethod rail) async {
    final snapshot = state.snapshot;
    final availability = snapshot?.quoteRailAvailability;
    if (snapshot == null ||
        !snapshot.isFiatFixed ||
        availability == null ||
        !availability.supports(rail) ||
        snapshot.timeUntilExpiry(_now()) == Duration.zero) {
      return;
    }
    if (state.quoteRefreshing && state.selectedQuoteRail == rail) return;

    final operation = ++_quoteOperation;
    final current = state.quote;
    final keepCurrent =
        current != null &&
        current.selectedRail == rail &&
        !current.isExpired(_now());
    if (!keepCurrent) _quoteExpiryTimer?.cancel();
    emit(
      state.copyWith(
        selectedQuoteRail: rail,
        quoteRefreshing: true,
        clearQuote: !keepCurrent,
        clearQuoteFailure: true,
      ),
    );

    final result = await _facade.quote(invoiceId: _invoiceId, rail: rail);
    if (isClosed || operation != _quoteOperation) return;
    switch (result) {
      case Ok(:final value):
        if (value.invoiceId != _invoiceId ||
            value.selectedRail != rail ||
            value.isExpired(_now()) ||
            !_quoteLineageCanAdvance(value)) {
          emit(
            state.copyWith(
              quoteRefreshing: false,
              quoteFailure: const InvoicesFailure.invalidServerResponse(),
              clearQuote: true,
            ),
          );
          _quoteExpiryTimer?.cancel();
          return;
        }
        emit(
          state.copyWith(
            quote: value,
            quoteRefreshing: false,
            clearQuoteFailure: true,
          ),
        );
        _recordAcceptedQuote(value);
        _scheduleQuoteExpiry(value);
      case Err(:final failure):
        final active = state.quote;
        emit(
          state.copyWith(
            quoteRefreshing: false,
            quoteFailure: failure,
            clearQuote: active == null || active.isExpired(_now()),
          ),
        );
    }
  }

  void quoteExpired() {
    final quote = state.quote;
    if (quote == null) return;
    if (!quote.isExpired(_now())) {
      _scheduleQuoteExpiry(quote);
      return;
    }
    final rail = quote.selectedRail;
    _quoteExpiryTimer?.cancel();
    emit(state.copyWith(clearQuote: true));
    unawaited(refreshQuote(rail));
  }

  Future<void> cancel() async {
    if (state.cancelling || !state.canCancel) return;
    emit(state.copyWith(cancelling: true, clearCancelFailure: true));
    final result = await _facade.cancel(
      CancelInvoiceCommand(
        invoiceId: _invoiceId,
        nymOwner: state.invoice?.nymOwner,
      ),
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            cancelling: false,
            cancelFinalStatus: value.finalStatus,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(cancelling: false, cancelFailure: failure));
    }
    // Reflect the settled state after either outcome (and stop polling once
    // terminal).
    await _fetch();
  }

  Future<void> _fetch() async {
    final result = await _facade.status(_invoiceId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        final quoteUnavailable =
            !value.isFiatFixed ||
            value.quoteRailAvailability == null ||
            value.timeUntilExpiry(_now()) == Duration.zero ||
            (state.selectedQuoteRail != null &&
                !value.quoteRailAvailability!.supports(
                  state.selectedQuoteRail!,
                ));
        if (quoteUnavailable) _quoteExpiryTimer?.cancel();
        emit(
          state.copyWith(
            status: InvoiceDetailStatus.loaded,
            snapshot: value,
            clearFailure: true,
            clearQuote: quoteUnavailable,
          ),
        );
      case Err(:final failure):
        // Keep a prior snapshot visible; only flip to error on the first load.
        if (state.snapshot == null) {
          emit(
            state.copyWith(status: InvoiceDetailStatus.error, failure: failure),
          );
        } else {
          emit(state.copyWith(failure: failure));
        }
    }
    if (isClosed) return;
    await _fetchFallbackSupervision();
  }

  Future<void> _fetchFallbackSupervision() async {
    final result = await _facade.fallbackSupervision();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            fallbackSupervisions: value.forInvoice(_invoiceId),
            fallbackSupervisionOverflow: value.hasMore,
            clearFallbackSupervisionFailure: true,
          ),
        );
      case Err(:final failure):
        // Keep the last authenticated projection visible. This failure must
        // not hide a successfully loaded public invoice snapshot.
        emit(state.copyWith(fallbackSupervisionFailure: failure));
    }
  }

  Future<void> _ensureInitialQuote() async {
    final snapshot = state.snapshot;
    if (snapshot == null || !snapshot.isFiatFixed || state.quote != null) {
      return;
    }
    final rail = snapshot.quoteRailAvailability?.firstAvailable;
    if (rail != null) await refreshQuote(rail);
  }

  bool _quoteLineageCanAdvance(InvoiceQuote incoming) {
    final current = _lastAcceptedQuote;
    if (current == null) return true;
    if (incoming.versionNumber < current.versionNumber) return false;
    if (incoming.versionNumber > current.versionNumber) return true;
    return incoming.versionId == current.versionId &&
        incoming.createdAt == current.createdAt &&
        incoming.expiresAt == current.expiresAt &&
        incoming.fiatFaceAmountMinor == current.fiatFaceAmountMinor &&
        incoming.fiatTargetAmountMinor == current.fiatTargetAmountMinor &&
        incoming.fiatCurrency == current.fiatCurrency &&
        incoming.rateMinorPerBtc == current.rateMinorPerBtc &&
        incoming.rateSource == current.rateSource &&
        incoming.rateObservedAt == current.rateObservedAt &&
        incoming.rateFetchedAt == current.rateFetchedAt &&
        incoming.rateFreshUntil == current.rateFreshUntil &&
        incoming.instruction.amount.merchantTargetAmountSat ==
            current.instruction.amount.merchantTargetAmountSat &&
        (_acceptedInstructionFingerprints[incoming.selectedRail] == null ||
            _acceptedInstructionFingerprints[incoming.selectedRail] ==
                _instructionFingerprint(incoming.instruction));
  }

  void _recordAcceptedQuote(InvoiceQuote quote) {
    final previous = _lastAcceptedQuote;
    if (previous == null || quote.versionNumber > previous.versionNumber) {
      _acceptedInstructionFingerprints.clear();
    }
    _acceptedInstructionFingerprints[quote.selectedRail] =
        _instructionFingerprint(quote.instruction);
    _lastAcceptedQuote = quote;
  }

  String _instructionFingerprint(
    InvoiceQuoteInstruction instruction,
  ) => switch (instruction) {
    InvoiceLightningQuoteInstruction(
      :final quoteOfferId,
      :final pr,
      :final amount,
    ) =>
      '${amount.payerAmountSat}\u0000$quoteOfferId\u0000$pr',
    InvoiceLiquidQuoteInstruction(:final address, :final amount) =>
      '${amount.payerAmountSat}\u0000$address',
    InvoiceBitcoinQuoteInstruction(
      :final quoteOfferId,
      :final address,
      :final bip21,
      :final amount,
    ) =>
      '${amount.payerAmountSat}\u0000${quoteOfferId ?? ''}\u0000$address\u0000$bip21',
  };

  void _scheduleQuoteExpiry(InvoiceQuote quote) {
    _quoteExpiryTimer?.cancel();
    final remaining = quote.timeUntilExpiry(_now());
    if (remaining == Duration.zero) {
      quoteExpired();
      return;
    }
    _quoteExpiryTimer = Timer(remaining, quoteExpired);
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
    _quoteOperation++;
    _quoteExpiryTimer?.cancel();
    return super.close();
  }
}
