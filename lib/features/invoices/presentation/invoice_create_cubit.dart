import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/domain/entities/private_invoice_presentation.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_create_state.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InvoiceCreateCubit extends Cubit<InvoiceCreateState> {
  final InvoicesFacade _facade;
  int _operationId = 0;

  InvoiceCreateCubit({required InvoicesFacade facade}) : this._(facade);

  InvoiceCreateCubit._(this._facade) : super(const InvoiceCreateState());

  Future<void> initialize() async {
    final result = await _facade.resumeCreate();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        if (value != null) {
          emit(state.copyWith(initializing: false, result: value));
          return;
        }
      case Err(:final failure):
        emit(
          state.copyWith(
            initializing: false,
            pendingRetry: true,
            failure: failure,
          ),
        );
        return;
    }
    emit(state.copyWith(initializing: false));
    await _loadCurrencies();
  }

  Future<void> retryPending() async {
    if (state.submitting || !state.pendingRetry) return;
    final op = ++_operationId;
    emit(state.copyWith(submitting: true, clearFailure: true));
    final result = await _facade.resumeCreate();
    if (isClosed || op != _operationId) return;
    switch (result) {
      case Ok(:final value):
        if (value == null) {
          emit(
            state.copyWith(
              submitting: false,
              pendingRetry: false,
              clearFailure: true,
            ),
          );
          await _loadCurrencies();
        } else {
          emit(state.copyWith(submitting: false, result: value));
        }
      case Err(:final failure):
        emit(state.copyWith(submitting: false, failure: failure));
    }
  }

  Future<void> _loadCurrencies() async {
    final result = await _facade.supportedCurrencies();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        final currencies = value.currencies;
        emit(
          state.copyWith(
            currencies: currencies,
            currenciesUnavailable: false,
            fiatCurrency: state.fiatCurrency.isEmpty && currencies.isNotEmpty
                ? currencies.first.code
                : state.fiatCurrency,
          ),
        );
      case Err(:final failure):
        log.warning(
          'Invoice currency fetch failed',
          error: failure.logMessage ?? failure.code,
        );
        emit(state.copyWith(currenciesUnavailable: true));
    }
  }

  void amountModeChanged(InvoiceAmountMode value) => _emit(
    state.copyWith(
      amountMode: value,
      clearInvalidField: state.invalidField == InvoiceCreateField.amount,
    ),
  );
  void amountChanged(String value) => _emit(
    state.copyWith(
      amountInput: value,
      clearInvalidField: state.invalidField == InvoiceCreateField.amount,
    ),
  );
  void fiatCurrencyChanged(String value) => _emit(
    state.copyWith(
      fiatCurrency: value,
      clearInvalidField: state.invalidField == InvoiceCreateField.currency,
    ),
  );
  void acceptBtcChanged(bool value) => _emit(state.copyWith(acceptBtc: value));
  void acceptLnChanged(bool value) => _emit(state.copyWith(acceptLn: value));
  void acceptLiquidChanged(bool value) =>
      _emit(state.copyWith(acceptLiquid: value));

  void detailChanged(InvoiceCreateField field, String value) {
    final next = switch (field) {
      InvoiceCreateField.payerName => state.copyWith(payerName: value),
      InvoiceCreateField.payerCorporateName => state.copyWith(
        payerCorporateName: value,
      ),
      InvoiceCreateField.payerAddress => state.copyWith(payerAddress: value),
      InvoiceCreateField.payerEmail => state.copyWith(payerEmail: value),
      InvoiceCreateField.payerPhone => state.copyWith(payerPhone: value),
      InvoiceCreateField.description => state.copyWith(description: value),
      InvoiceCreateField.invoiceNumber => state.copyWith(invoiceNumber: value),
      InvoiceCreateField.purchaseOrderReference => state.copyWith(
        purchaseOrderReference: value,
      ),
      InvoiceCreateField.invoiceDate => state.copyWith(invoiceDate: value),
      InvoiceCreateField.paymentDeadline => state.copyWith(
        paymentDeadline: value,
      ),
      InvoiceCreateField.payeeName => state.copyWith(payeeName: value),
      InvoiceCreateField.payeeCorporateName => state.copyWith(
        payeeCorporateName: value,
      ),
      InvoiceCreateField.payeeAddress => state.copyWith(payeeAddress: value),
      InvoiceCreateField.payeeEmail => state.copyWith(payeeEmail: value),
      InvoiceCreateField.payeePhone => state.copyWith(payeePhone: value),
      _ => state,
    };
    _emit(
      next.copyWith(
        clearInvalidField:
            state.invalidField == field ||
            state.invalidField == InvoiceCreateField.details,
      ),
    );
  }

  Future<void> submit() async {
    if (state.initializing ||
        state.submitting ||
        state.isSubmitted ||
        state.pendingRetry) {
      return;
    }
    if (!state.hasAnyRail) {
      emit(
        state.copyWith(
          failure: const InvoicesFailure.invalidInput(code: 'NoRailSelected'),
        ),
      );
      return;
    }
    final amount = _parseAmount();
    if (amount == null) return;

    final PrivateInvoicePresentation presentation;
    try {
      presentation = PrivateInvoicePresentation(
        payer: _contact(
          section: 'payer',
          name: state.payerName,
          corporateName: state.payerCorporateName,
          address: state.payerAddress,
          email: state.payerEmail,
          phone: state.payerPhone,
        ),
        invoice: _invoiceDetails(),
        payee: _contact(
          section: 'payee',
          name: state.payeeName,
          corporateName: state.payeeCorporateName,
          address: state.payeeAddress,
          email: state.payeeEmail,
          phone: state.payeePhone,
        ),
      );
    } on PrivateInvoicePresentationException catch (error) {
      emit(
        state.copyWith(
          failure: InvoicesFailure.invalidInput(
            code: '${error.field}:${error.code}',
          ),
          invalidField: _fieldFor(error.field),
        ),
      );
      return;
    }

    final op = ++_operationId;
    emit(
      state.copyWith(
        submitting: true,
        clearFailure: true,
        clearInvalidField: true,
      ),
    );
    final result = await _facade.create(
      CreateInvoiceCommand(
        amountSat: amount.$1,
        fiatAmountMinor: amount.$2,
        fiatCurrency: amount.$3,
        presentation: presentation,
        acceptBtc: state.acceptBtc,
        acceptLn: state.acceptLn,
        acceptLiquid: state.acceptLiquid,
      ),
    );
    if (isClosed || op != _operationId) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(submitting: false, result: value));
      case Err(:final failure):
        emit(
          state.copyWith(
            submitting: false,
            pendingRetry:
                failure.kind == InvoicesFailureKind.outcomeUnknown ||
                failure.kind == InvoicesFailureKind.privateStorage ||
                failure.kind == InvoicesFailureKind.createConflict,
            failure: failure,
          ),
        );
    }
  }

  (int?, int?, String?)? _parseAmount() {
    if (state.amountMode == InvoiceAmountMode.sats) {
      final value = int.tryParse(state.amountInput.trim());
      if (value == null || value <= 0) {
        _emitInvalid(InvoiceCreateField.amount, 'AmountInvalid');
        return null;
      }
      return (value, null, null);
    }
    if (state.fiatCurrency.isEmpty) {
      _emitInvalid(InvoiceCreateField.currency, 'CurrencyRequired');
      return null;
    }
    final value = double.tryParse(state.amountInput.trim());
    if (value == null || value <= 0) {
      _emitInvalid(InvoiceCreateField.amount, 'AmountInvalid');
      return null;
    }
    final factor = _pow10(_precisionFor(state.fiatCurrency));
    return (null, (value * factor).round(), state.fiatCurrency);
  }

  PrivateInvoiceContact _contact({
    required String section,
    required String name,
    required String corporateName,
    required String address,
    required String email,
    required String phone,
  }) {
    try {
      return PrivateInvoiceContact(
        name: name,
        corporateName: corporateName,
        address: address,
        email: email,
        phone: phone,
      );
    } on PrivateInvoicePresentationException catch (error) {
      throw PrivateInvoicePresentationException(
        field: '$section.${error.field}',
        code: error.code,
      );
    }
  }

  PrivateInvoiceDetails _invoiceDetails() {
    try {
      return PrivateInvoiceDetails(
        description: state.description,
        number: state.invoiceNumber,
        purchaseOrderReference: state.purchaseOrderReference,
        invoiceDate: state.invoiceDate,
        paymentDeadline: state.paymentDeadline,
      );
    } on PrivateInvoicePresentationException catch (error) {
      throw PrivateInvoicePresentationException(
        field: 'invoice.${error.field}',
        code: error.code,
      );
    }
  }

  InvoiceCreateField _fieldFor(String field) => switch (field) {
    'payer.name' => InvoiceCreateField.payerName,
    'payer.corporate_name' => InvoiceCreateField.payerCorporateName,
    'payer.address' => InvoiceCreateField.payerAddress,
    'payer.email' => InvoiceCreateField.payerEmail,
    'payer.phone' => InvoiceCreateField.payerPhone,
    'invoice.description' => InvoiceCreateField.description,
    'invoice.number' => InvoiceCreateField.invoiceNumber,
    'invoice.purchase_order_reference' =>
      InvoiceCreateField.purchaseOrderReference,
    'invoice.invoice_date' => InvoiceCreateField.invoiceDate,
    'invoice.payment_deadline' => InvoiceCreateField.paymentDeadline,
    'payee.name' => InvoiceCreateField.payeeName,
    'payee.corporate_name' => InvoiceCreateField.payeeCorporateName,
    'payee.address' => InvoiceCreateField.payeeAddress,
    'payee.email' => InvoiceCreateField.payeeEmail,
    'payee.phone' => InvoiceCreateField.payeePhone,
    _ => InvoiceCreateField.details,
  };

  void _emitInvalid(InvoiceCreateField field, String code) {
    emit(
      state.copyWith(
        failure: InvoicesFailure.invalidInput(code: code),
        invalidField: field,
      ),
    );
  }

  int _precisionFor(String currency) {
    for (final item in state.currencies) {
      if (item.code == currency) return item.precision;
    }
    return 2;
  }

  int _pow10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  void _emit(InvoiceCreateState next) {
    emit(next.copyWith(clearFailure: true));
  }
}
