import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';

enum InvoiceAmountMode { sats, fiat }

enum InvoiceCreateField {
  amount,
  currency,
  payerName,
  payerCorporateName,
  payerAddress,
  payerEmail,
  payerPhone,
  description,
  invoiceNumber,
  purchaseOrderReference,
  invoiceDate,
  paymentDeadline,
  payeeName,
  payeeCorporateName,
  payeeAddress,
  payeeEmail,
  payeePhone,
  details,
}

class InvoiceCreateState {
  final bool initializing;
  final bool submitting;
  final bool pendingRetry;
  final CreateInvoiceResult? result;
  final InvoicesFailure? failure;
  final InvoiceAmountMode amountMode;
  final String amountInput;
  final String fiatCurrency;
  final bool acceptBtc;
  final bool acceptLn;
  final bool acceptLiquid;
  final String payerName;
  final String payerCorporateName;
  final String payerAddress;
  final String payerEmail;
  final String payerPhone;
  final String description;
  final String invoiceNumber;
  final String purchaseOrderReference;
  final String invoiceDate;
  final String paymentDeadline;
  final String payeeName;
  final String payeeCorporateName;
  final String payeeAddress;
  final String payeeEmail;
  final String payeePhone;
  final List<BullnymSupportedCurrency> currencies;
  final bool currenciesUnavailable;
  final InvoiceCreateField? invalidField;

  const InvoiceCreateState({
    this.initializing = true,
    this.submitting = false,
    this.pendingRetry = false,
    this.result,
    this.failure,
    this.amountMode = InvoiceAmountMode.sats,
    this.amountInput = '',
    this.fiatCurrency = '',
    this.acceptBtc = false,
    this.acceptLn = true,
    this.acceptLiquid = true,
    this.payerName = '',
    this.payerCorporateName = '',
    this.payerAddress = '',
    this.payerEmail = '',
    this.payerPhone = '',
    this.description = '',
    this.invoiceNumber = '',
    this.purchaseOrderReference = '',
    this.invoiceDate = '',
    this.paymentDeadline = '',
    this.payeeName = '',
    this.payeeCorporateName = '',
    this.payeeAddress = '',
    this.payeeEmail = '',
    this.payeePhone = '',
    this.currencies = const [],
    this.currenciesUnavailable = false,
    this.invalidField,
  });

  bool get isSubmitted => result != null;
  bool get hasAnyRail => acceptBtc || acceptLn || acceptLiquid;

  int get populatedFieldCount => [
    payerName,
    payerCorporateName,
    payerAddress,
    payerEmail,
    payerPhone,
    description,
    invoiceNumber,
    purchaseOrderReference,
    invoiceDate,
    paymentDeadline,
    payeeName,
    payeeCorporateName,
    payeeAddress,
    payeeEmail,
    payeePhone,
  ].where((value) => value.trim().isNotEmpty).length;

  InvoiceCreateState copyWith({
    bool? initializing,
    bool? submitting,
    bool? pendingRetry,
    CreateInvoiceResult? result,
    InvoicesFailure? failure,
    InvoiceAmountMode? amountMode,
    String? amountInput,
    String? fiatCurrency,
    bool? acceptBtc,
    bool? acceptLn,
    bool? acceptLiquid,
    String? payerName,
    String? payerCorporateName,
    String? payerAddress,
    String? payerEmail,
    String? payerPhone,
    String? description,
    String? invoiceNumber,
    String? purchaseOrderReference,
    String? invoiceDate,
    String? paymentDeadline,
    String? payeeName,
    String? payeeCorporateName,
    String? payeeAddress,
    String? payeeEmail,
    String? payeePhone,
    List<BullnymSupportedCurrency>? currencies,
    bool? currenciesUnavailable,
    InvoiceCreateField? invalidField,
    bool clearFailure = false,
    bool clearInvalidField = false,
  }) {
    return InvoiceCreateState(
      initializing: initializing ?? this.initializing,
      submitting: submitting ?? this.submitting,
      pendingRetry: pendingRetry ?? this.pendingRetry,
      result: result ?? this.result,
      failure: clearFailure ? null : failure ?? this.failure,
      amountMode: amountMode ?? this.amountMode,
      amountInput: amountInput ?? this.amountInput,
      fiatCurrency: fiatCurrency ?? this.fiatCurrency,
      acceptBtc: acceptBtc ?? this.acceptBtc,
      acceptLn: acceptLn ?? this.acceptLn,
      acceptLiquid: acceptLiquid ?? this.acceptLiquid,
      payerName: payerName ?? this.payerName,
      payerCorporateName: payerCorporateName ?? this.payerCorporateName,
      payerAddress: payerAddress ?? this.payerAddress,
      payerEmail: payerEmail ?? this.payerEmail,
      payerPhone: payerPhone ?? this.payerPhone,
      description: description ?? this.description,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      purchaseOrderReference:
          purchaseOrderReference ?? this.purchaseOrderReference,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      paymentDeadline: paymentDeadline ?? this.paymentDeadline,
      payeeName: payeeName ?? this.payeeName,
      payeeCorporateName: payeeCorporateName ?? this.payeeCorporateName,
      payeeAddress: payeeAddress ?? this.payeeAddress,
      payeeEmail: payeeEmail ?? this.payeeEmail,
      payeePhone: payeePhone ?? this.payeePhone,
      currencies: currencies ?? this.currencies,
      currenciesUnavailable:
          currenciesUnavailable ?? this.currenciesUnavailable,
      invalidField: clearInvalidField
          ? null
          : invalidField ?? this.invalidField,
    );
  }
}
