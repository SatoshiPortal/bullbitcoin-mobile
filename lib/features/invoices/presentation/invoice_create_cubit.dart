import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_create_state.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the create-invoice form. It holds only form state; on [submit] it
/// builds a [CreateInvoiceCommand] and delegates to the facade — the payout
/// wallet lookup, address generation, signing and label storage all live in the
/// usecase. An [_operationId] guard makes double-taps and stale completions
/// inert (§CR-01).
class InvoiceCreateCubit extends Cubit<InvoiceCreateState> {
  final InvoicesFacade _facade;
  int _operationId = 0;

  InvoiceCreateCubit({required this._facade})
    : super(const InvoiceCreateState());

  /// Loads the live fiat currency list; degrades gracefully on failure so the
  /// sats path still works (§7.4).
  Future<void> loadCurrencies() async {
    try {
      final supported = await _facade.supportedCurrencies();
      if (isClosed) return;
      final currencies = supported.currencies;
      emit(
        state.copyWith(
          currencies: currencies,
          currenciesUnavailable: false,
          fiatCurrency: state.fiatCurrency.isEmpty && currencies.isNotEmpty
              ? currencies.first.code
              : state.fiatCurrency,
        ),
      );
    } catch (e, stack) {
      log.warning('Invoice currency fetch failed', error: e, trace: stack);
      if (isClosed) return;
      emit(state.copyWith(currenciesUnavailable: true));
    }
  }

  void amountModeChanged(InvoiceAmountMode mode) => emit(
    state.copyWith(
      amountMode: mode,
      clearFailure: true,
      clearInvalidField: true,
    ),
  );

  void amountChanged(String value) => emit(
    state.copyWith(
      amountInput: value,
      clearFailure: true,
      clearInvalidField: state.invalidField == InvoiceCreateField.amount,
    ),
  );

  void fiatCurrencyChanged(String code) => emit(
    state.copyWith(
      fiatCurrency: code,
      clearFailure: true,
      clearInvalidField: state.invalidField == InvoiceCreateField.currency,
    ),
  );

  void publicDescriptionChanged(String value) =>
      emit(state.copyWith(publicDescription: value, clearFailure: true));

  void recipientNameChanged(String value) =>
      emit(state.copyWith(recipientName: value, clearFailure: true));

  void invoiceNumberChanged(String value) =>
      emit(state.copyWith(invoiceNumber: value, clearFailure: true));

  void acceptBtcChanged(bool value) =>
      emit(state.copyWith(acceptBtc: value, clearFailure: true));

  void acceptLnChanged(bool value) =>
      emit(state.copyWith(acceptLn: value, clearFailure: true));

  void acceptLiquidChanged(bool value) =>
      emit(state.copyWith(acceptLiquid: value, clearFailure: true));

  void expiryDaysChanged(int days) =>
      emit(state.copyWith(expiryDays: days.clamp(1, 7), clearFailure: true));

  void privateMemoChanged(String value) =>
      emit(state.copyWith(privateMemo: value, clearFailure: true));

  Future<void> submit() async {
    if (state.submitting || state.isSubmitted) return;

    // Light local pre-checks (the usecase + server remain the authority): a
    // rail must be chosen and the amount must parse. Deeper coherence is typed
    // back from the usecase.
    if (!state.hasAnyRail) {
      emit(
        state.copyWith(
          failure: const InvoicesFailure.invalidInput(code: 'NoRailSelected'),
        ),
      );
      return;
    }
    final int? amountSat;
    final int? fiatAmountMinor;
    final String? fiatCurrency;
    if (state.amountMode == InvoiceAmountMode.sats) {
      amountSat = int.tryParse(state.amountInput.trim());
      fiatAmountMinor = null;
      fiatCurrency = null;
      if (amountSat == null || amountSat <= 0) {
        _emitInvalidAmount();
        return;
      }
    } else {
      amountSat = null;
      fiatCurrency = state.fiatCurrency;
      if (fiatCurrency.isEmpty) {
        emit(
          state.copyWith(
            failure: const InvoicesFailure.invalidInput(
              code: 'CurrencyRequired',
            ),
            invalidField: InvoiceCreateField.currency,
          ),
        );
        return;
      }
      fiatAmountMinor = _parseFiatMinor(state.amountInput, fiatCurrency);
      if (fiatAmountMinor == null || fiatAmountMinor <= 0) {
        _emitInvalidAmount();
        return;
      }
    }

    final op = ++_operationId;
    emit(
      state.copyWith(
        submitting: true,
        clearFailure: true,
        clearInvalidField: true,
      ),
    );

    final command = CreateInvoiceCommand(
      amountSat: amountSat,
      fiatAmountMinor: fiatAmountMinor,
      fiatCurrency: fiatCurrency,
      publicDescription: _nullIfBlank(state.publicDescription),
      recipientName: _nullIfBlank(state.recipientName),
      invoiceNumber: _nullIfBlank(state.invoiceNumber),
      acceptBtc: state.acceptBtc,
      acceptLn: state.acceptLn,
      acceptLiquid: state.acceptLiquid,
      expiresAt: DateTime.now().toUtc().add(Duration(days: state.expiryDays)),
      privateMemo: _nullIfBlank(state.privateMemo),
    );

    final result = await _facade.create(command);
    if (isClosed || op != _operationId) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(submitting: false, result: value));
      case Err(:final failure):
        emit(state.copyWith(submitting: false, failure: failure));
    }
  }

  void _emitInvalidAmount() => emit(
    state.copyWith(
      failure: const InvoicesFailure.invalidInput(code: 'AmountInvalid'),
      invalidField: InvoiceCreateField.amount,
    ),
  );

  int _precisionFor(String currency) {
    for (final c in state.currencies) {
      if (c.code == currency) return c.precision;
    }
    return 2;
  }

  /// Converts a decimal amount string to minor units for the currency's
  /// precision (e.g. "12.34"/CAD → 1234; "5000"/COP(0) → 5000).
  int? _parseFiatMinor(String input, String currency) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final value = double.tryParse(trimmed);
    if (value == null) return null;
    final factor = _pow10(_precisionFor(currency));
    return (value * factor).round();
  }

  int _pow10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
